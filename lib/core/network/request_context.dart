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
/// 本对象、ApiService 的取消令牌和进度回调都没有 Dio 类型，因此更换网络实现时，
/// 请求 ID、幂等键以及 Repository 的方法签名都不需要跟着修改。
class RequestContext {
  /// 创建单次请求上下文。
  ///
  /// 所有参数都有安全默认值：没有临时 Header/ID，写请求不允许网络重试，普通 JSON
  /// 请求允许 Token 刷新后重放。创建订单、支付、上传等请求应根据服务端幂等能力
  /// 显式覆盖 [idempotencyKey]、[allowRetry] 和 [replayPolicy]，不要机械复制配置。
  const RequestContext({
    this.headers = const {},
    this.requestId,
    this.idempotencyKey,
    this.allowRetry = false,
    this.replayPolicy = RequestReplayPolicy.automatic,
    this.extra = const {},
  });

  /// 仅用于该请求的额外 Header。
  ///
  /// key 是 Header 名，value 是 Dio 可序列化值。禁止放全局 token、Cookie 或密码；
  /// 认证 Header 由 TokenInterceptor 统一注入。调用方传入同名 Header 时可能覆盖
  /// 基础配置，因此只应由 Repository/基础设施创建，不接受页面任意 Map。
  final Map<String, Object?> headers;

  /// 调用方已有链路 ID 时可透传；为空则 RequestMetadataInterceptor 自动生成。
  /// 它会进入 `X-Request-Id` Header 和本地日志 context，用于串联客户端/服务端日志，
  /// 不是业务订单号，也不应用作安全凭据。
  final String? requestId;

  /// 写请求幂等键。ApiClient 会映射成 `Idempotency-Key` Header。
  ///
  /// 它必须在同一次业务操作的所有重试中保持稳定，在下一次新操作中更换；只有服务端
  /// 真正按该键去重才有效，客户端单独生成字符串不能保证幂等。
  final String? idempotencyKey;

  /// 是否允许 RetryInterceptor 重试非 GET/HEAD 请求。
  /// POST/PUT/PATCH/DELETE 默认不能安全重试，只有确认服务端幂等后才设为 true，
  /// 并且必须同时提供非空 [idempotencyKey]；缺少任一条件时拦截器都不会重试。
  /// 该开关只影响超时/连接错误重试，不等同于 401 Token 刷新后的 [replayPolicy]。
  final bool allowRetry;

  /// 是否允许 401 刷新 Token 成功后自动重放原请求。
  /// 敏感写操作、文件流或无法重新构造的 body 应设为 never。设为 never 后，新 token
  /// 仍会保存供下一次手工请求使用，但当前 401 会继续返回给调用方。
  final RequestReplayPolicy replayPolicy;

  /// 给自定义拦截器传递、不发送给服务器的 Dio extra 元数据。
  ///
  /// 可放功能标记或采样信息，不能放业务 Model、BuildContext 或需要跨网络传输的值。
  /// `requestId`、`allowRetry`、`replayDisabled` 等底座内部 key 由 ApiClient 管理，
  /// 项目自定义 key 应加前缀避免冲突。
  final Map<String, Object?> extra;
}
