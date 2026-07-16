// lib/core/errors/app_failure.dart
//
// Core 层不能依赖中文文案或 Widget，所以异常只描述“发生了哪类失败”和
// “供排查的技术信息”。shared 的 FailureMessageResolver 再把类别映射为用户文案。
// 这样未来切换语言不会修改网络层，日志也不会丢失真正的诊断细节。

/// 跨网络、存储和业务模块都能理解的稳定失败分类。
enum FailureKind {
  /// 无网、DNS、连接拒绝等网络可达性问题。
  network,

  /// 连接、发送或接收超过限定时间。
  timeout,

  /// 服务端或网关返回异常状态。
  server,

  /// 登录失效、凭据过期或未认证。
  authentication,

  /// 已认证但没有执行当前操作的权限。
  permission,

  /// 本地输入或领域参数校验失败。
  validation,

  /// 请求成功到达后端，但业务规则拒绝执行。
  business,

  /// 数据库、普通偏好或安全存储失败。
  storage,

  /// 调用方主动取消或生命周期结束，不应当作普通失败提示。
  cancellation,

  /// 服务端响应结构、字段类型或版本与客户端契约不一致。
  protocol,

  /// 无法安全归类的兜底失败。
  unknown,
}

/// 跨层传递的稳定失败对象。
///
/// Service/Repository 可以把 Dio、SQLite 或平台插件异常转换成它，ViewModel 只按
/// [kind] 决定页面状态，不需要 import 三方异常类型。用户文案由 shared 层解析。
class AppFailure implements Exception {
  /// 创建跨层稳定失败。
  ///
  /// - [kind]：展示层和状态工具依赖的稳定类别；
  /// - [debugMessage]：仅供日志/监控的技术描述；
  /// - [failureCode]：可选 HTTP、业务或本地错误码；
  /// - [suggestedMessage]：只有明确审核为可展示内容时才填写；
  /// - [cause]：被包装的原始异常，帮助监控追踪根因。
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
