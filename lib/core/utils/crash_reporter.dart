// 可替换的崩溃与非致命异常上报入口。

import 'logger.dart';

/// 崩溃平台适配端口。
///
/// 接口刻意只保留所有平台共有的最小能力。接入具体 SDK 时在实现类中完成
/// SDK 专有字段映射，业务层不应该出现 Firebase/Sentry 等厂商类型。
abstract interface class CrashReportingBackend {
  /// 初始化远程 SDK；默认由 AppWarmup 在首帧完成后调用，不阻塞页面出现。
  Future<void> initialize();

  /// 上报异常。
  ///
  /// - [error]：原始异常对象；
  /// - [stack]：可空调用栈，没有捕获到时传 null；
  /// - [fatal]：是否为导致应用流程终止的致命错误，会影响平台告警和崩溃率统计。
  void capture(Object error, StackTrace? stack, {bool fatal});

  /// 设置会附加到后续事件的上下文。
  ///
  /// [key] 应使用稳定名称，如 `userId`/`environment`；[value] 传 null 通常表示清除
  /// 旧值。不得写入 token、密码、身份证号等敏感信息。
  void setContext(String key, Object? value);

  /// 记录崩溃前的关键步骤，帮助还原用户操作链。
  ///
  /// [message] 是稳定动作描述，[data] 是非敏感附加字段。不要把整个请求/响应对象
  /// 直接放入 breadcrumb。
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

  /// 替换全局崩溃平台实现。
  ///
  /// [backend] 应在 runApplication 构建 ProviderScope 前配置一次；configure 本身只
  /// 保存实现，不执行厂商 SDK 的耗时初始化，真正初始化由 [initialize] 延迟完成。
  static void configure(CrashReportingBackend backend) {
    // 在 App 启动早期替换一次。后续所有全局错误处理器都会使用同一个实现。
    _backend = backend;
  }

  /// 初始化当前 backend。通常由首帧后的 AppWarmup 调用，失败交给预热结果记录。
  static Future<void> initialize() => _backend.initialize();

  /// 安全上报异常，不允许上报 SDK 的故障反向打断业务。
  ///
  /// [error]/[stack]/[fatal] 含义与 [CrashReportingBackend.capture] 相同。捕获到但已经
  /// 恢复的异常保持 fatal=false；FlutterError 或 PlatformDispatcher 未处理错误才
  /// 应按实际情况标记 fatal。
  static void report(Object error, StackTrace? stack, {bool fatal = false}) {
    try {
      // 上报 SDK 自身异常不能覆盖真正的业务异常，更不能触发新的全局崩溃。
      _backend.capture(error, stack, fatal: fatal);
    } on Object catch (reportingError) {
      AppLogger.warning('Crash reporting failed', error: reportingError);
    }
  }

  /// 给后续崩溃事件设置/清除全局上下文；参数规则见 backend 的 setContext。
  static void setContext(String key, Object? value) {
    try {
      _backend.setContext(key, value);
    } on Object catch (reportingError) {
      AppLogger.warning('Crash context update failed', error: reportingError);
    }
  }

  /// 添加安全的操作轨迹；参数规则见 backend 的 addBreadcrumb。
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
