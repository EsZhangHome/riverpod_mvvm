// 可替换的结构化日志入口。正式项目可注入远程日志实现，业务调用方不变。

import 'package:flutter/foundation.dart';

/// 日志严重级别。
///
/// 使用枚举而不是让调用方传任意字符串，方便远程日志平台按等级检索、告警和采样。
enum LogLevel {
  /// 只用于本地排查的细节信息，生产环境通常采样或关闭。
  debug,

  /// 正常业务阶段和关键流程信息。
  info,

  /// 流程可继续但需要关注的异常情况。
  warning,

  /// 当前操作失败或发生需要告警的错误。
  error,
}

/// 与具体日志 SDK 无关的一条结构化日志。
///
/// Model 中只保存通用 Dart 类型，意味着以后接入 Sentry、Datadog 或公司平台时，
/// 只需要写一个 [LogSink] 适配器，业务代码不需要批量替换 SDK 调用。
class LogRecord {
  /// 创建一条结构化日志记录。
  ///
  /// - [level]：严重等级；
  /// - [message]：可读且相对稳定的事件描述；
  /// - [timestamp]：事件发生时间，AppLogger 固定传 UTC；
  /// - [error]/[stackTrace]：可选异常对象和调用栈；
  /// - [context]：用于检索聚合的非敏感键值。
  const LogRecord({
    required this.level,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
    this.context = const {},
  });

  /// 本条日志的严重等级。
  final LogLevel level;

  /// 日志正文。不要直接插入密码、token、请求体或完整响应体。
  final String message;

  /// 统一使用 UTC，避免服务端汇总不同时区设备日志时产生歧义。
  final DateTime timestamp;

  /// error 和 stackTrace 分开保存，后端可以分别建立异常分组与调用栈索引。
  final Object? error;
  final StackTrace? stackTrace;

  /// requestId、userId 等可检索字段；禁止写入 token、密码等敏感数据。
  final Map<String, Object?> context;
}

/// 日志输出端口。
///
/// core 只定义能力，不依赖任何厂商 SDK，这是“依赖倒置”在基础设施层的应用。
abstract interface class LogSink {
  /// 输出 [record]。实现可以送到控制台、内存或远程平台。
  void write(LogRecord record);
}

/// 本地开发输出端。
///
/// [enabled] 是环境配置开关，`kDebugMode` 是编译模式保护；两者同时满足才输出，
/// 防止正式包因错误配置意外打印用户数据或网络上下文。
class DebugLogSink implements LogSink {
  /// 创建本地调试输出端。
  ///
  /// - [prefix]：每行日志的固定标签，多个应用/模块共用控制台时用于区分来源；
  /// - [enabled]：环境级开关。即使为 true，release 构建仍会被 kDebugMode 阻止。
  const DebugLogSink({this.prefix = 'RiverpodMVVM', this.enabled = true});

  /// 控制台每行开头的固定标签。
  final String prefix;

  /// 是否允许当前 Sink 输出；它不能绕过 kDebugMode 的 release 保护。
  final bool enabled;

  @override
  void write(LogRecord record) {
    if (!enabled || !kDebugMode) return;
    // context 保持结构化 Map 的字符串形式，调试时比手工拼接字段更容易核对。
    final context = record.context.isEmpty ? '' : ' ${record.context}';
    debugPrint(
      '[$prefix][${record.level.name.toUpperCase()}] '
      '${record.message}$context',
    );
    if (record.error != null) debugPrint('[$prefix] ${record.error}');
    if (record.stackTrace != null) debugPrint('${record.stackTrace}');
  }
}

/// 完全丢弃日志的实现，适合不允许输出日志的测试或特殊构建。
class NoopLogSink implements LogSink {
  const NoopLogSink();

  @override
  void write(LogRecord record) {}
}

/// 全项目统一的日志门面。
///
/// 为什么这里使用静态门面而不是每个 ViewModel 都注入 Logger：日志属于跨层旁路能力，
/// 若让每个业务构造器都携带它会制造大量无业务价值的参数。真正需要替换的部分仍通过
/// [LogSink] 注入，测试也可以配置内存 Sink 收集记录。
abstract final class AppLogger {
  static LogSink _sink = const DebugLogSink();
  static Map<String, Object?> _globalContext = const {};

  /// 配置全局日志输出端和公共上下文。
  ///
  /// - [sink]：真正消费 LogRecord 的实现；
  /// - [globalContext]：每条日志都会携带的字段，如 environment/appVersion。
  ///
  /// globalContext 会复制为不可变 Map。局部日志 context 与其同名时，局部值覆盖
  /// 全局值；这里不要放用户 token 等敏感字段。
  static void configure(
    LogSink sink, {
    Map<String, Object?> globalContext = const {},
  }) {
    _sink = sink;
    // 不可变副本防止调用方稍后修改原 Map，导致每条日志的全局上下文悄悄变化。
    _globalContext = Map.unmodifiable(globalContext);
  }

  /// 兼容简单调用；把任意 [message] 转成字符串并按 info 级别记录。
  ///
  /// 新代码优先使用 debug/info/warning/error，以明确等级并传结构化 context。
  static void log(Object message) => info(message.toString());

  /// 记录调试信息。[context] 只放非敏感检索字段。
  static void debug(String message, {Map<String, Object?> context = const {}}) {
    _write(LogLevel.debug, message, context: context);
  }

  /// 记录正常流程信息。[context] 只放非敏感检索字段。
  static void info(String message, {Map<String, Object?> context = const {}}) {
    _write(LogLevel.info, message, context: context);
  }

  /// 记录可恢复警告。
  ///
  /// [error]/[stackTrace] 可用于定位异常，[context] 用于聚合；调用本方法不会抛出
  /// Sink 内部错误。
  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    _write(
      LogLevel.warning,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// 记录当前操作失败或严重错误；参数含义同 [warning]。
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    _write(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void _write(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    // 局部 context 放在展开运算符后面，因此同名 key 会覆盖全局默认值。
    // 例如全局记录 environment，某次请求可以补充自己的 requestId。
    final record = LogRecord(
      level: level,
      message: message,
      timestamp: DateTime.now().toUtc(),
      error: error,
      stackTrace: stackTrace,
      context: {..._globalContext, ...context},
    );
    try {
      // 日志平台属于旁路能力，SDK 故障不能反向打断登录、请求或启动流程。
      _sink.write(record);
    } on Object catch (sinkError) {
      if (kDebugMode) debugPrint('[AppLogger fallback] $sinkError');
    }
  }
}
