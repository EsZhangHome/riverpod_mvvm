// lib/app/bootstrap/app_bootstrap.dart
//
// AppBootstrap 是“关键启动用例”，不是 Widget，也不是全局 Service Locator。
//
// 这里只执行“不完成就不能安全创建业务 Provider”的任务：
// 1. 校验当前构建配置是否安全；
// 2. 准备恢复隐私同意、登录用户和主题所需的最小本地存储。
//
// 数据库、埋点和其他非首屏能力不放在这里。它们分别由按需 Provider 和
// AppWarmup 处理，否则每增加一个 SDK 都会让用户更晚看到第一帧。

import '../../core/config/env_config.dart';
import '../../core/storage/local_storage.dart';
import '../../core/performance/performance_reporter.dart';
import '../../core/utils/crash_reporter.dart';

/// 关键启动流程的最终状态。
///
/// - [ready]：所有关键准备步骤成功，可以正常创建业务 Widget 树；
/// - [degraded]：非安全关键步骤失败，但已有明确降级方案，例如普通偏好不可用时
///   回退到默认主题，因此仍允许进入 App；
/// - [failed]：继续启动可能使用不安全配置，目前会停留在启动失败页。
enum BootstrapStatus { ready, degraded, failed }

/// 一个启动阶段的失败记录。
///
/// 这里保存诊断信息，不负责决定页面文案。这样启动页可以显示安全提示，监控平台
/// 仍能拿到原始错误和堆栈定位问题。
class BootstrapIssue {
  /// 创建一条启动失败记录。
  ///
  /// - [stage]：稳定阶段名，例如 `configuration`、`storage`，用于 UI 和监控聚合；
  /// - [error]：真正捕获到的异常对象，只用于诊断，不直接显示给用户；
  /// - [stackTrace]：异常发生时的调用栈；
  /// - [isCritical]：true 表示该失败必须阻止进入业务，false 表示允许降级。
  const BootstrapIssue({
    required this.stage,
    required this.error,
    required this.stackTrace,
    required this.isCritical,
  });

  /// 稳定阶段名用于页面提示和监控聚合，不直接使用异常类型当阶段名。
  final String stage;

  /// 原始异常。页面不得直接调用 toString 展示，避免泄露配置和设备细节。
  final Object error;

  /// 原始调用栈，供 CrashReporter 或远程监控定位失败代码。
  final StackTrace stackTrace;

  /// critical 表示继续启动可能不安全；当前配置错误属于 critical。
  final bool isCritical;
}

/// 关键启动任务的不可变结果，也是 BootstrapGate 与业务 ProviderScope 的交接对象。
class BootstrapResult {
  /// 创建启动结果。
  ///
  /// [status] 决定是否允许进入业务；[issues] 保存本次所有已捕获问题。调用方应
  /// 传入不可变列表，AppBootstrap 已通过 List.unmodifiable 保证这一点。
  const BootstrapResult({required this.status, this.issues = const []});

  /// 无任何启动问题时的便捷构造函数。
  const BootstrapResult.ready()
    : status = BootstrapStatus.ready,
      issues = const [];

  /// 本次启动的总体状态。
  final BootstrapStatus status;

  /// 本次启动捕获到的问题；ready 时为空，degraded/failed 时至少包含一项。
  final List<BootstrapIssue> issues;

  /// degraded 仍允许启动，页面可通过 bootstrapResultProvider 展示降级提示。
  bool get canStart => status != BootstrapStatus.failed;
}

/// 可以被测试或项目组合层替换的异步启动步骤。
///
/// 返回的 Future 完成表示步骤成功；抛出异常表示失败，由 AppBootstrap 统一分类、
/// 上报并决定降级，而不是让 action 自己操作启动页面。
typedef BootstrapAction = Future<void> Function();

/// 环境校验是纯同步计算，单独定义类型可避免测试依赖真实 dart-define。
typedef ConfigurationAction = void Function();

/// 执行首帧前关键任务的用例对象。
///
/// 这里不继承 Riverpod Notifier，因为它必须在业务 ProviderScope 创建前运行；
/// 创建 ProviderScope 后的状态和依赖，才交给 Riverpod 管理。
class AppBootstrap {
  /// 创建关键启动用例。
  ///
  /// 两个 action 都允许从构造函数替换，不是为了增加抽象层，而是为了让测试
  /// 不必真的启动 SharedPreferences。测试注入普通闭包，就能稳定验证成功、
  /// 配置阻断和存储降级三条路径。
  ///
  /// - [validateConfiguration]：同步安全校验。为空时调用 EnvConfig.ensureValid；
  ///   一旦抛错会直接返回 failed，不再执行存储初始化。
  /// - [initializeStorage]：准备普通偏好存储。为空时调用 LocalStorage.init；失败会
  ///   记录为 degraded，因为主题仍能使用默认值、安全会话仍走 SecureStorage。
  /// - [stageTimeout]：单个异步阶段最多等待多久，默认 5 秒。超时只结束当前等待并
  ///   进入降级流程，Dart Future 本身不具备强制中止底层插件工作的能力。
  AppBootstrap({
    ConfigurationAction? validateConfiguration,
    BootstrapAction? initializeStorage,
    this.stageTimeout = const Duration(seconds: 5),
  }) : _validateConfiguration = validateConfiguration ?? EnvConfig.ensureValid,
       _initializeStorage = initializeStorage ?? _initializeLocalStorage;

  final ConfigurationAction _validateConfiguration;
  final BootstrapAction _initializeStorage;

  /// 每个异步启动阶段的最长等待时间，而不是整个 App 的总启动时限。
  final Duration stageTimeout;

  static Future<void> _initializeLocalStorage() async {
    await LocalStorage.init();
    // LocalStorage 为业务读写提供降级，但启动编排仍需知道它是否真的可用，
    // 这样监控平台和启动页才能区分“正常启动”和“降级启动”。
    if (!LocalStorage.isInitialized) {
      throw StateError('LocalStorage initialization failed');
    }
  }

  /// 按固定顺序执行配置校验和最小存储初始化。
  ///
  /// 本方法不向外抛出已知启动异常，而是将其转换成 [BootstrapResult]：
  /// - 配置异常 → failed；
  /// - 普通存储异常或超时 → degraded；
  /// - 全部成功 → ready。
  ///
  /// 原始异常会同步交给 CrashReporter。调用方只需根据 result.canStart 决定显示
  /// 失败页还是创建业务 ProviderScope。
  Future<BootstrapResult> initialize() async {
    final issues = <BootstrapIssue>[];

    try {
      // 配置校验必须最先且同步完成。不安全配置下不应创建业务 Provider 或进入登录页。
      _validateConfiguration();
    } catch (error, stack) {
      issues.add(
        BootstrapIssue(
          stage: 'configuration',
          error: error,
          stackTrace: stack,
          isCritical: true,
        ),
      );
      CrashReporter.report(error, stack, fatal: true);
      return BootstrapResult(
        status: BootstrapStatus.failed,
        issues: List.unmodifiable(issues),
      );
    }

    // LocalStorage 必须在内层业务 ProviderScope 之前尝试初始化：themeProvider
    // 首次构建会同步恢复隐私版本和主题，SessionStore 也可能读取旧版用户 JSON 做迁移。
    // 失败时仍允许降级启动：主题回退默认值，新格式安全会话不依赖 LocalStorage。
    await _runStage('storage', _initializeStorage, issues);

    return BootstrapResult(
      status: issues.isEmpty ? BootstrapStatus.ready : BootstrapStatus.degraded,
      issues: List.unmodifiable(issues),
    );
  }

  Future<void> _runStage(
    String stage,
    BootstrapAction action,
    List<BootstrapIssue> issues,
  ) async {
    try {
      await AppPerformance.measure(
        'bootstrap.$stage',
        () => action().timeout(stageTimeout),
      );
    } catch (error, stack) {
      // 收集而不是 rethrow：普通存储不可用时仍可以使用内存登录态和系统主题，
      // 所以 App 以 degraded 模式继续启动，而不是把用户永久拦在启动页。
      final issue = BootstrapIssue(
        stage: stage,
        error: error,
        stackTrace: stack,
        isCritical: false,
      );
      issues.add(issue);
      CrashReporter.report(error, stack);
    }
  }
}
