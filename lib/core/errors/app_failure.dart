// lib/core/errors/app_failure.dart
//
// Core 层不能依赖中文文案或 Widget，所以异常只描述“发生了哪类失败”和
// “供排查的技术信息”。shared 的 FailureMessageResolver 再把类别映射为用户文案。
// 这样未来切换语言不会修改网络层，日志也不会丢失真正的诊断细节。

/// 跨网络、存储和业务模块都能理解的稳定失败分类。
enum FailureKind {
  network,
  timeout,
  server,
  authentication,
  permission,
  validation,
  business,
  storage,
  cancellation,
  protocol,
  unknown,
}

/// 跨层传递的稳定失败对象。
///
/// Service/Repository 可以把 Dio、SQLite 或平台插件异常转换成它，ViewModel 只按
/// [kind] 决定页面状态，不需要 import 三方异常类型。用户文案由 shared 层解析。
class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.debugMessage,
    this.failureCode,
    this.suggestedMessage,
    this.cause,
  });

  /// 展示层据此选择安全、本地化的用户提示。
  final FailureKind kind;

  /// 仅供日志和监控，不应未经处理直接显示给用户。
  final String debugMessage;

  /// HTTP 状态码、后端业务码或本地错误码，便于检索问题。
  final Object? failureCode;

  /// 少数已确认安全的业务提示可放这里；基础设施异常通常保持 null。
  final String? suggestedMessage;

  /// 保留原始异常链，接监控平台时可继续追踪根因。
  final Object? cause;

  /// 取消可能来自页面销毁、刷新替换旧请求或用户主动停止，不应当成失败弹 Toast
  /// 或进入 error 页面。
  bool get isCancellation => kind == FailureKind.cancellation;

  @override
  String toString() => 'AppFailure($kind, $failureCode, $debugMessage)';
}
