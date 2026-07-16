// lib/app/bootstrap/app_bootstrap.dart
//
// AppBootstrap 是“关键启动用例”，不是 Widget，也不是全局 Service Locator。
//
// 这里只执行“不完成就不能安全创建业务 Provider”的任务：
// 1. 校验当前构建配置是否安全；
// 2. 准备恢复登录用户和主题所需的最小本地存储。
//
// 数据库、埋点和其他非首屏能力不放在这里。它们分别由按需 Provider 和
// AppWarmup 处理，否则每增加一个 SDK 都会让用户更晚看到第一帧。

import '../../core/config/env_config.dart';
import '../../core/storage/local_storage.dart';
import '../../core/performance/performance_reporter.dart';
import '../../core/utils/crash_reporter.dart';

/// ready：全部正常；degraded：非关键能力失败但可继续；failed：禁止进入业务。
enum BootstrapStatus { ready, degraded, failed }

/// 一个启动阶段的失败记录。
///
/// 这里保存诊断信息，不负责决定页面文案。这样启动页可以显示安全提示，监控平台
/// 仍能拿到原始错误和堆栈定位问题。
class BootstrapIssue {
  const BootstrapIssue({
    required this.stage,
    required this.error,
    required this.stackTrace,
    required this.isCritical,
  });

  /// 稳定阶段名用于页面提示和监控聚合，不直接使用异常类型当阶段名。
  final String stage;
  final Object error;
  final StackTrace stackTrace;

  /// critical 表示继续启动可能不安全；当前配置错误属于 critical。
  final bool isCritical;
}

/// 关键启动任务的不可变结果，也是 BootstrapGate 与业务 ProviderScope 的交接对象。
class BootstrapResult {
  const BootstrapResult({required this.status, this.issues = const []});

  const BootstrapResult.ready()
    : status = BootstrapStatus.ready,
      issues = const [];

  final BootstrapStatus status;
  final List<BootstrapIssue> issues;

  /// degraded 仍允许启动，页面可通过 bootstrapResultProvider 展示降级提示。
  bool get canStart => status != BootstrapStatus.failed;
}

/// 可以被测试替换的异步启动步骤。
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
  AppBootstrap({
    ConfigurationAction? validateConfiguration,
    BootstrapAction? initializeStorage,
    this.stageTimeout = const Duration(seconds: 5),
  }) : _validateConfiguration = validateConfiguration ?? EnvConfig.ensureValid,
       _initializeStorage = initializeStorage ?? _initializeLocalStorage;

  final ConfigurationAction _validateConfiguration;
  final BootstrapAction _initializeStorage;
  final Duration stageTimeout;

  static Future<void> _initializeLocalStorage() async {
    await LocalStorage.init();
    // LocalStorage 为业务读写提供降级，但启动编排仍需知道它是否真的可用，
    // 这样监控平台和启动页才能区分“正常启动”和“降级启动”。
    if (!LocalStorage.isInitialized) {
      throw StateError('LocalStorage initialization failed');
    }
  }

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
    // 首次构建会同步恢复主题，SessionStore 也可能读取旧版用户 JSON 做一次迁移。
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
