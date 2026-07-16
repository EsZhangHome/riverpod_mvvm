import 'privacy_consent_record.dart';
import 'privacy_policy_config.dart';

/// 隐私同意状态机。
///
/// 不使用 `isFirstLaunch`：真正有意义的是“是否存在历史同意版本”以及“历史版本是否
/// 等于当前版本”。这两个事实才能稳定地区分首次授权、政策升级和正常放行。
enum PrivacyConsentStatus {
  /// 本地没有任何历史同意版本。
  ///
  /// 这是首次安装、清除应用数据或主动撤回授权后的状态。App 可以创建登录页，但
  /// 必须等认证恢复确认进入登录页后自动展示一次协议说明。登录请求和需要授权的
  /// 三方能力仍不能执行。
  initialConsentRequired,

  /// 用户在本次进程中拒绝了首次自动提示。
  ///
  /// 该状态只解决“拒绝后关闭弹窗”的 UI 需求，不代表已经同意，也不会写入磁盘。
  /// 本次运行不再自动打扰；未勾选点击登录仍会再次请求弹窗。下次冷启动没有同意
  /// 记录，所以重新恢复为 [initialConsentRequired] 并再次自动提示。
  initialConsentDismissedForSession,

  /// 本地存在历史同意版本，但它与当前政策版本不同。
  ///
  /// 这说明用户不是第一次使用 App，而是遇到了政策升级。业务页面可以保留，
  /// 但必须在最上层显示不可绕过的升级弹窗。
  policyUpgradeRequired,

  /// 用户在本次进程中拒绝了政策升级。
  ///
  /// 历史版本不会被删除，否则下次启动会被误判成“首次安装”。这个状态只存在于
  /// 内存中，用来关闭当前升级弹窗；下次启动仍会再次提示升级。
  upgradeDeclinedForSession,

  /// 已同意当前政策版本，可以发起登录请求并启动需要授权的业务能力。
  granted,
}

/// 保存或撤回同意记录时可能出现的稳定失败类型。
///
/// View 只根据枚举展示本地化文案，原始异常由 ViewModel 上报，避免把插件错误直接
/// 显示给用户。
enum PrivacyConsentFailure {
  /// 当前政策版本写入普通偏好失败。
  persistFailed,

  /// 主动撤回时删除已同意版本失败。
  revokeFailed,
}

/// App 级隐私同意状态。
final class PrivacyConsentState {
  const PrivacyConsentState({
    required this.status,
    required this.policy,
    required this.acceptedRecord,
    this.isSaving = false,
    this.failure,
  });

  /// 根据持久化版本恢复状态。
  factory PrivacyConsentState.restore({
    required PrivacyPolicyConfig policy,
    required PrivacyConsentRecord? acceptedRecord,
  }) {
    final normalizedVersion = acceptedRecord?.consentVersion.trim();
    final hasAcceptedBefore = normalizedVersion?.isNotEmpty ?? false;
    final status = normalizedVersion == policy.version
        ? PrivacyConsentStatus.granted
        : hasAcceptedBefore
        ? PrivacyConsentStatus.policyUpgradeRequired
        : PrivacyConsentStatus.initialConsentRequired;
    return PrivacyConsentState(
      status: status,
      policy: policy,
      acceptedRecord: hasAcceptedBefore ? acceptedRecord : null,
    );
  }

  final PrivacyConsentStatus status;

  /// 当前构建要求同意的政策，而不是历史政策。
  final PrivacyPolicyConfig policy;

  /// 本地读到的历史同意记录；null 表示从未同意或记录不可用。
  final PrivacyConsentRecord? acceptedRecord;

  /// 兼容页面判断和旧测试命名的便捷 getter，事实来源仍是 [acceptedRecord]。
  String? get acceptedVersion => acceptedRecord?.consentVersion;

  /// true 表示正在持久化，页面应禁用重复点击。
  final bool isSaving;

  /// 最近一次保存/撤回失败；成功操作会清空。
  final PrivacyConsentFailure? failure;

  bool get hasAcceptedCurrentPolicy =>
      status == PrivacyConsentStatus.granted &&
      acceptedRecord?.consentVersion == policy.version;

  /// 是否曾经同意过某个历史版本。
  ///
  /// 这是区分“首次授权”和“政策升级”的关键，不能用启动次数代替。
  bool get hasAcceptedAnyPolicy =>
      acceptedRecord?.consentVersion.isNotEmpty ?? false;

  /// 是否应在业务页面最上层显示政策升级弹窗。
  bool get shouldShowPolicyUpgrade =>
      status == PrivacyConsentStatus.policyUpgradeRequired;

  PrivacyConsentState copyWith({
    PrivacyConsentStatus? status,
    PrivacyConsentRecord? acceptedRecord,
    bool clearAcceptedRecord = false,
    bool? isSaving,
    PrivacyConsentFailure? failure,
    bool clearFailure = false,
  }) {
    return PrivacyConsentState(
      status: status ?? this.status,
      policy: policy,
      acceptedRecord: clearAcceptedRecord
          ? null
          : acceptedRecord ?? this.acceptedRecord,
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
