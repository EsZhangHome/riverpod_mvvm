// lib/app/bootstrap/app_warmup.dart
//
// AppWarmup 负责“首帧出现以后再做”的非关键初始化。
//
// 它和 AppBootstrap 的区别：
// - AppBootstrap 失败可能阻止或降级创建业务 ProviderScope；
// - AppWarmup 永远不遮挡首屏，某个任务失败只记录问题，其他任务继续执行；
// - 数据库也不属于 Warmup，它由 databaseServiceProvider 在第一次 CRUD 时打开。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/crash_reporter.dart';
import '../../core/performance/performance_reporter.dart';

/// 一个不需要 BuildContext、可在首帧后运行的异步预热动作。
/// Future 完成表示成功，异常由 AppWarmupNotifier 捕获并记录，不会覆盖首页。
typedef WarmupAction = Future<void> Function();

/// 非关键任务可以选择的启动时机。
///
/// 两个阶段都发生在 BootstrapGate 放行业务 App 之后，因此不会阻塞原生启动图：
/// - [afterFirstFrame]：MyApp 第一帧后立即运行，适合崩溃监控等越早可用越好的旁路能力；
/// - [afterSessionReady]：安全会话恢复且目标路由画出一帧后运行，适合远程配置、
///   更新检查和统计 SDK，避免它们与 SecureStorage 争抢启动期 IO。
enum AppWarmupPhase { afterFirstFrame, afterSessionReady }

/// 一个可独立执行的后台预热任务。
///
/// [name] 使用稳定英文标识，便于日志平台聚合，例如 monitoring、remote_config。
/// [run] 是真正的异步操作。任务不接收 BuildContext，避免后台逻辑依赖页面。
class AppWarmupTask {
  /// 创建预热任务。
  ///
  /// - [name]：稳定、低基数的英文任务名，会成为性能指标的一部分；不要包含用户
  ///   id、订单号等动态值；
  /// - [run]：真正初始化 SDK 或拉取非关键配置的异步函数；
  /// - [phase]：任务应该在哪个非阻塞阶段启动，默认等会话恢复完成；
  /// - [timeout]：此任务最多等待多久，默认 10 秒。超时会记为 issue，但不能从
  ///   Dart 层强制杀死一个不支持取消的三方 Future。
  const AppWarmupTask({
    required this.name,
    required this.run,
    this.phase = AppWarmupPhase.afterSessionReady,
    this.timeout = const Duration(seconds: 10),
  });

  /// 性能指标和问题聚合使用的任务标识。
  final String name;

  /// 实际执行的异步动作。
  final WarmupAction run;

  /// 当前任务的调度阶段。阶段只影响何时开始，不改变失败降级规则。
  final AppWarmupPhase phase;

  /// 当前任务的独立超时时间，不影响其他并行任务。
  final Duration timeout;
}

/// 单个预热任务的失败信息。
///
/// 保留原始异常和调用栈用于诊断，但页面若需要提示用户，应转换成本地化安全文案，
/// 不要直接展示 [error.toString]。
class AppWarmupIssue {
  /// 创建预热问题记录。
  ///
  /// [task] 对应 AppWarmupTask.name；[error] 与 [stackTrace] 只用于日志、监控和
  /// 调试，不能未经转换直接展示到页面。
  const AppWarmupIssue({
    required this.task,
    required this.error,
    required this.stackTrace,
  });

  /// 失败任务的稳定名称。
  final String task;

  /// 捕获到的原始异常。
  final Object error;

  /// 原始异常调用栈。
  final StackTrace stackTrace;
}

/// 一次预热执行结束后的不可变结果。
class AppWarmupResult {
  /// 创建一次预热汇总；[issues] 为空表示全部任务成功。
  const AppWarmupResult({this.issues = const []});

  /// 所有失败或超时任务；成功任务不会进入列表。
  final List<AppWarmupIssue> issues;

  /// true 只表示所有预热任务成功，不影响 App 是否可以继续使用。
  bool get isSuccessful => issues.isEmpty;
}

/// 预热任务注册表。
///
/// 底座默认只完成监控 SDK 的完整初始化。真实项目可以 override 或在自己的
/// 组合层提供任务列表，加入远程配置、更新检查等非关键工作。不要加入数据库、
/// 地图、支付等只有特定功能使用的重型 SDK，它们应该继续按需初始化。
///
/// 示例：
/// ```dart
/// appWarmupTasksProvider.overrideWithValue([
///   AppWarmupTask(
///     name: 'monitoring',
///     phase: AppWarmupPhase.afterFirstFrame,
///     run: crashBackend.initialize,
///   ),
///   // 不传 phase 默认等会话恢复和目标页首帧完成。
///   AppWarmupTask(name: 'remote_config', run: remoteConfig.initialize),
/// ]);
/// ```
final appWarmupTasksProvider = Provider<List<AppWarmupTask>>((ref) {
  return [
    AppWarmupTask(
      name: 'monitoring',
      phase: AppWarmupPhase.afterFirstFrame,
      run: CrashReporter.initialize,
    ),
  ];
});

/// App 级预热状态管理器。
///
/// State 的含义：
/// - AsyncData(null)：尚未开始；
/// - AsyncLoading：任务正在后台运行；
/// - AsyncData(result)：全部任务都已结束，result 可能包含非致命失败。
///
/// 失败被收集进 AppWarmupResult，而不是变成 AsyncError，因为预热任务互相独立，
/// 其中一个失败不应该让其他任务停止，也不应该把已经显示的首页切成错误页。
class AppWarmupNotifier extends AsyncNotifier<AppWarmupResult?> {
  /// 每个阶段对应的唯一执行 Future。重复/并发调用会复用同一个 Future。
  final Map<AppWarmupPhase, Future<void>> _phaseRuns = {};

  /// 已完成阶段收集到的所有问题。任务失败不会阻止另一个阶段继续执行。
  final List<AppWarmupIssue> _issues = [];

  /// 可能同时运行的阶段数量，用于避免一个阶段提前结束时错误显示“全部完成”。
  int _runningPhaseCount = 0;

  /// 首次状态为 AsyncData(null)，表示“还没有调用 start”，不是加载失败或空数据。
  @override
  FutureOr<AppWarmupResult?> build() => null;

  /// 启动全部预热阶段，主要供测试、后台预加载或不区分页面时机的入口使用。
  ///
  /// App 正常运行时优先调用 [startPhase]，让早期监控和会话后的普通任务按时机分开。
  /// 本方法并发请求两个阶段，但同一阶段仍只执行一次。
  Future<void> start() async {
    await Future.wait(AppWarmupPhase.values.map(startPhase));
  }

  /// 启动指定 [phase] 的任务。
  ///
  /// 同一阶段无论被 Widget 重建、多个入口或 [start] 调用多少次，都复用第一次创建
  /// 的 Future，确保厂商 SDK 不会重复 initialize。阶段内任务并行执行，每个任务
  /// 单独超时和捕获异常。
  Future<void> startPhase(AppWarmupPhase phase) {
    return _phaseRuns.putIfAbsent(phase, () => _runPhase(phase));
  }

  Future<void> _runPhase(AppWarmupPhase phase) async {
    _runningPhaseCount++;
    state = const AsyncLoading();

    // 只选当前阶段任务。列表为空也算成功完成，后续重复调用不会重新扫描或执行。
    final tasks = ref
        .read(appWarmupTasksProvider)
        .where((task) => task.phase == phase);
    // 阶段内任务彼此独立并行执行，避免远程配置和更新检查互相排队。
    // 每个任务内部单独捕获异常，因此 Future.wait 本身不会因单点失败提前结束。
    final taskIssues = await Future.wait(tasks.map(_runTask));
    _issues.addAll(taskIssues.whereType<AppWarmupIssue>());
    _runningPhaseCount--;
    if (!ref.mounted || _runningPhaseCount > 0) return;

    state = AsyncData(
      AppWarmupResult(
        issues: List.unmodifiable(
          <AppWarmupIssue>[..._issues]
            ..sort((left, right) => left.task.compareTo(right.task)),
        ),
      ),
    );
  }

  Future<AppWarmupIssue?> _runTask(AppWarmupTask task) async {
    try {
      await AppPerformance.measure(
        'warmup.${task.name}',
        () => task.run().timeout(task.timeout),
      );
      return null;
    } catch (error, stackTrace) {
      // 预热失败属于非致命问题。统一上报后返回 Issue，既保留诊断信息，
      // 又不会把异常重新抛到 Flutter 全局错误处理器。
      CrashReporter.report(error, stackTrace);
      return AppWarmupIssue(
        task: task.name,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// 非 autoDispose 的 App 级 Provider：预热结果应在整个进程内保留。
final appWarmupProvider =
    AsyncNotifierProvider<AppWarmupNotifier, AppWarmupResult?>(
      AppWarmupNotifier.new,
    );
