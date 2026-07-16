// lib/core/network/request_context.dart
//
// 单次请求经常需要请求 ID、幂等键或临时 Header。如果 Repository 直接接收
// Dio Options，它就和 Dio 强耦合，测试与替换网络库都会困难。RequestContext
// 只表达业务无关的请求语义，由 ApiClient 最后翻译成 Dio Options。

/// 自动重放策略。
///
/// 文件流、支付、创建订单等请求即使拿到了新 Token，也不一定能安全重放。
enum RequestReplayPolicy {
  /// 普通 JSON 请求允许在刷新 Token 后重放；网络重试仍受 allowRetry 控制。
  automatic,

  /// 永不自动重放，由业务明确提示用户或重新构造请求。
  never,
}

/// 单次网络请求携带的附加上下文。
///
/// 对象不可变，可以安全地从 ViewModel 传到 Repository 再传给 ApiService。
/// 本对象自身没有 Dio 类型，因此更换网络实现时，请求 ID、幂等键等参数不需要
/// 跟着修改。ApiService 目前公开的 CancelToken/ProgressCallback 仍需单独迁移。
class RequestContext {
  const RequestContext({
    this.headers = const {},
    this.requestId,
    this.idempotencyKey,
    this.allowRetry = false,
    this.replayPolicy = RequestReplayPolicy.automatic,
    this.extra = const {},
  });

  /// 仅用于该请求的 Header。禁止放全局 token；token 由拦截器统一注入。
  final Map<String, Object?> headers;

  /// 调用方已有链路 ID 时可透传；为空则 RequestMetadataInterceptor 自动生成。
  final String? requestId;

  /// 防止创建订单、支付等写请求因重试而重复执行；服务端也必须支持此键。
  final String? idempotencyKey;

  /// POST/PUT/PATCH 默认不能安全重试，只有确认服务端幂等后才设为 true。
  final bool allowRetry;

  /// 是否允许拦截器自动重放原请求。敏感写操作应设为 never。
  final RequestReplayPolicy replayPolicy;

  /// 给自定义拦截器传递不进入 Header 的本地元数据。
  final Map<String, Object?> extra;
}
