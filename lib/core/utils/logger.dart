// 可替换的结构化日志入口。正式项目可注入远程日志实现，业务调用方不变。

import 'package:flutter/foundation.dart';

/// 日志严重级别。
///
/// 使用枚举而不是让调用方传任意字符串，方便远程日志平台按等级检索、告警和采样。
enum LogLevel { debug, info, warning, error }

/// 与具体日志 SDK 无关的一条结构化日志。
///
/// Model 中只保存通用 Dart 类型，意味着以后接入 Sentry、Datadog 或公司平台时，
/// 只需要写一个 [LogSink] 适配器，业务代码不需要批量替换 SDK 调用。
class LogRecord {
  const LogRecord({
    required this.level,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
    this.context = const {},
  });

  final LogLevel level;
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
  void write(LogRecord record);
}

/// 本地开发输出端。
///
/// [enabled] 是环境配置开关，`kDebugMode` 是编译模式保护；两者同时满足才输出，
/// 防止正式包因错误配置意外打印用户数据或网络上下文。
class DebugLogSink implements LogSink {
  const DebugLogSink({this.prefix = 'RiverpodMVVM', this.enabled = true});

  final String prefix;
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

  static void configure(
    LogSink sink, {
    Map<String, Object?> globalContext = const {},
  }) {
    _sink = sink;
    // 不可变副本防止调用方稍后修改原 Map，导致每条日志的全局上下文悄悄变化。
    _globalContext = Map.unmodifiable(globalContext);
  }

  /// 兼容原有调用；默认按 info 级别记录。
  static void log(Object message) => info(message.toString());

  static void debug(String message, {Map<String, Object?> context = const {}}) {
    _write(LogLevel.debug, message, context: context);
  }

  static void info(String message, {Map<String, Object?> context = const {}}) {
    _write(LogLevel.info, message, context: context);
  }

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
