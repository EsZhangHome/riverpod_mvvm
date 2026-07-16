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

typedef WarmupAction = Future<void> Function();

/// 一个可独立执行的后台预热任务。
///
/// [name] 使用稳定英文标识，便于日志平台聚合，例如 monitoring、remote_config。
/// [run] 是真正的异步操作。任务不接收 BuildContext，避免后台逻辑依赖页面。
class AppWarmupTask {
  const AppWarmupTask({
    required this.name,
    required this.run,
    this.timeout = const Duration(seconds: 10),
  });

  final String name;
  final WarmupAction run;
  final Duration timeout;
}

/// 单个预热任务的失败信息。
///
/// 保留原始异常和调用栈用于诊断，但页面若需要提示用户，应转换成本地化安全文案，
/// 不要直接展示 [error.toString]。
class AppWarmupIssue {
  const AppWarmupIssue({
    required this.task,
    required this.error,
    required this.stackTrace,
  });

  final String task;
  final Object error;
  final StackTrace stackTrace;
}

/// 一次预热执行结束后的不可变结果。
class AppWarmupResult {
  const AppWarmupResult({this.issues = const []});

  final List<AppWarmupIssue> issues;

  /// true 只表示所有预热任务成功，不影响 App 是否可以继续使用。
  bool get isSuccessful => issues.isEmpty;
}

/// 预热任务注册表。
///
/// 底座默认只完成监控 SDK 的完整初始化。真实项目可以 override 或在自己的
/// 组合层提供任务列表，加入远程配置、更新检查等非关键工作。不要加入数据库、
/// 地图、支付等只有特定功能使用的重型 SDK，它们应该继续按需初始化。
final appWarmupTasksProvider = Provider<List<AppWarmupTask>>((ref) {
  return [AppWarmupTask(name: 'monitoring', run: CrashReporter.initialize)];
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
  bool _started = false;

  @override
  FutureOr<AppWarmupResult?> build() => null;

  /// 启动一次预热。重复调用会直接返回，防止 Widget 重建导致 SDK 重复初始化。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    state = const AsyncLoading();

    // 并行执行彼此独立的任务，避免远程配置和监控初始化互相排队。
    // 每个任务内部单独捕获异常，因此 Future.wait 本身不会因单点失败提前结束。
    final taskIssues = await Future.wait(
      ref.read(appWarmupTasksProvider).map(_runTask),
    );
    if (!ref.mounted) return;

    state = AsyncData(
      AppWarmupResult(
        issues: List.unmodifiable(taskIssues.whereType<AppWarmupIssue>()),
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
