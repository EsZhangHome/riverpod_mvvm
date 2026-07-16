/// 隐私弹窗展示层正在等待完成的显式请求来源。
enum PrivacyPromptReason {
  /// 登录页协议未勾选，用户主动点击了登录。
  loginRequired,
}

/// App 级隐私弹窗协调状态。
///
/// 授权事实仍由 PrivacyConsentState 管理；本状态只描述“某个调用方是否正在等待同一
/// 个弹窗结果”和“拒绝升级的跨模块清理是否进行中”。两种职责拆开后，不会为了显示
/// Dialog 把 BuildContext 或 Navigator 塞进业务 ViewModel。
final class PrivacyPromptState {
  const PrivacyPromptState({
    this.requestId,
    this.reason,
    this.isHandlingDecline = false,
    this.declineFailed = false,
  });

  /// 每次新请求递增的身份。Presenter 只关心是否非 null，测试可用于确认没有叠加。
  final int? requestId;

  final PrivacyPromptReason? reason;

  /// true 表示正在退出登录/清理会话，Dialog 必须继续遮挡页面并禁用操作。
  final bool isHandlingDecline;

  /// 升级拒绝后的退出动作失败。失败时保留弹窗，允许用户重试。
  final bool declineFailed;

  bool get hasPendingRequest => requestId != null;

  PrivacyPromptState copyWith({
    int? requestId,
    bool clearRequest = false,
    PrivacyPromptReason? reason,
    bool? isHandlingDecline,
    bool? declineFailed,
  }) {
    return PrivacyPromptState(
      requestId: clearRequest ? null : requestId ?? this.requestId,
      reason: clearRequest ? null : reason ?? this.reason,
      isHandlingDecline: isHandlingDecline ?? this.isHandlingDecline,
      declineFailed: declineFailed ?? this.declineFailed,
    );
  }
}
