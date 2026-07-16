// 可替换的崩溃与非致命异常上报入口。

import 'logger.dart';

/// 崩溃平台适配端口。
///
/// 接口刻意只保留所有平台共有的最小能力。接入具体 SDK 时在实现类中完成
/// SDK 专有字段映射，业务层不应该出现 Firebase/Sentry 等厂商类型。
abstract interface class CrashReportingBackend {
  /// 初始化远程 SDK；默认由 AppWarmup 在首帧完成后调用，不阻塞页面出现。
  Future<void> initialize();

  /// 上报异常。[fatal] 用来区分崩溃与可恢复错误，影响平台告警等级。
  void capture(Object error, StackTrace? stack, {bool fatal});

  /// 设置会附加到后续事件的上下文，如匿名用户编号或环境名。
  void setContext(String key, Object? value);

  /// 记录崩溃前的关键步骤，帮助还原用户操作链。
  void addBreadcrumb(String message, {Map<String, Object?> data});
}

/// 默认开发实现：不联网，只把事件送入统一日志入口。
///
/// 底座因此可以零配置运行；真实项目替换 backend 后，调用方完全不变。
class DebugCrashReportingBackend implements CrashReportingBackend {
  const DebugCrashReportingBackend();

  @override
  // Debug 实现没有 SDK 需要初始化，但仍返回 Future 以保持接口一致。
  Future<void> initialize() async {}

  @override
  void capture(Object error, StackTrace? stack, {bool fatal = false}) {
    AppLogger.error(
      fatal ? 'Fatal error' : 'Non-fatal error',
      error: error,
      stackTrace: stack,
    );
  }

  @override
  // Debug 环境没有持久的用户上下文，故有意为空实现。
  void setContext(String key, Object? value) {}

  @override
  void addBreadcrumb(String message, {Map<String, Object?> data = const {}}) {
    AppLogger.debug(message, context: data);
  }
}

/// 全项目统一的崩溃上报门面。
///
/// Flutter 框架错误和异步 Dart 错误由 run_application.dart 接入这里；业务代码也可
/// 上报已捕获的非致命异常。同步 capture/context/breadcrumb 调用会在门面内隔离
/// backend 异常；异步 initialize 由 AppWarmup 捕获并记录为非致命预热失败。
abstract final class CrashReporter {
  static CrashReportingBackend _backend = const DebugCrashReportingBackend();

  static void configure(CrashReportingBackend backend) {
    // 在 App 启动早期替换一次。后续所有全局错误处理器都会使用同一个实现。
    _backend = backend;
  }

  static Future<void> initialize() => _backend.initialize();

  static void report(Object error, StackTrace? stack, {bool fatal = false}) {
    try {
      // 上报 SDK 自身异常不能覆盖真正的业务异常，更不能触发新的全局崩溃。
      _backend.capture(error, stack, fatal: fatal);
    } on Object catch (reportingError) {
      AppLogger.warning('Crash reporting failed', error: reportingError);
    }
  }

  static void setContext(String key, Object? value) {
    try {
      _backend.setContext(key, value);
    } on Object catch (reportingError) {
      AppLogger.warning('Crash context update failed', error: reportingError);
    }
  }

  static void addBreadcrumb(
    String message, {
    Map<String, Object?> data = const {},
  }) {
    try {
      _backend.addBreadcrumb(message, data: data);
    } on Object catch (reportingError) {
      AppLogger.warning('Crash breadcrumb failed', error: reportingError);
    }
  }
}
