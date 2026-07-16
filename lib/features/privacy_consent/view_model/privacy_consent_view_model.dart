import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure_observer.dart';
import '../model/privacy_consent_record.dart';
import '../model/privacy_consent_state.dart';
import '../privacy_consent_providers.dart';

/// App 级隐私同意状态管理器。
///
/// 使用 Notifier 而不是 AsyncNotifier：Bootstrap 已经初始化普通存储，首次读取是同步
/// 的；保存动作虽然异步，但 [PrivacyConsentState.isSaving] 已能准确表达按钮状态，
/// 不需要再叠加一层 AsyncLoading。
final class PrivacyConsentNotifier extends Notifier<PrivacyConsentState> {
  @override
  PrivacyConsentState build() {
    final policy = ref.watch(privacyPolicyConfigProvider);
    try {
      final repository = ref.watch(privacyConsentRepositoryProvider);
      final acceptedRecord = repository.readAcceptedPolicyRecord();
      return PrivacyConsentState.restore(
        policy: policy,
        acceptedRecord: acceptedRecord,
      );
    } catch (error, stackTrace) {
      // 读取异常不能乐观放行。记录诊断后按“没有同意记录”处理：登录页仍可展示，
      // 但真正提交登录时必须重新取得用户同意。
      FailureObserver.reportIfNeeded(error, stackTrace);
      return PrivacyConsentState.restore(policy: policy, acceptedRecord: null);
    }
  }

  /// 同意当前政策并持久化。
  ///
  /// 只有 Repository 明确返回 true 后才发布 granted；失败、异常、重复点击或 Provider
  /// 已销毁都返回 false，并且不会放行登录请求或需要授权的 Warmup 任务。
  Future<bool> acceptCurrentPolicy() async {
    if (state.isSaving || state.hasAcceptedCurrentPolicy) {
      return state.hasAcceptedCurrentPolicy;
    }
    state = state.copyWith(isSaving: true, clearFailure: true);

    try {
      final record = PrivacyConsentRecord(
        consentVersion: state.policy.version,
        documentVersion: state.policy.documentVersion,
        userAgreementDocumentVersion: state.policy.userAgreementDocumentVersion,
        acceptedAtUtc: ref.read(privacyConsentClockProvider)().toUtc(),
      );
      final saved = await ref
          .read(privacyConsentRepositoryProvider)
          .saveAcceptedPolicyRecord(record);
      if (!ref.mounted) return false;
      if (!saved) {
        state = state.copyWith(
          isSaving: false,
          failure: PrivacyConsentFailure.persistFailed,
        );
        return false;
      }
      state = state.copyWith(
        status: PrivacyConsentStatus.granted,
        acceptedRecord: record,
        isSaving: false,
        clearFailure: true,
      );
      return true;
    } catch (error, stackTrace) {
      FailureObserver.reportIfNeeded(error, stackTrace);
      if (ref.mounted) {
        state = state.copyWith(
          isSaving: false,
          failure: PrivacyConsentFailure.persistFailed,
        );
      }
      return false;
    }
  }

  /// 拒绝首次自动提示，只关闭本次运行中的自动弹窗。
  ///
  /// 这里不删除也不新增持久化数据，因此 `hasAcceptedCurrentPolicy` 仍为 false，
  /// Warmup 与登录请求继续被拦截。用户之后未勾选点击登录时，协调器会再次显示同一
  /// 个协议 Dialog；重新启动后也会因没有记录而重新进入首次提示状态。
  bool dismissInitialConsentForCurrentSession() {
    if (state.isSaving ||
        state.status != PrivacyConsentStatus.initialConsentRequired) {
      return false;
    }
    state = state.copyWith(
      status: PrivacyConsentStatus.initialConsentDismissedForSession,
      clearFailure: true,
    );
    return true;
  }

  /// 记录“本次运行暂不接受政策升级”。
  ///
  /// 这个动作故意不修改 SharedPreferences：
  /// - 保留旧版本，才能证明用户过去同意过政策，而不是首次安装；
  /// - 下次重新启动 App 时，状态会再次恢复成 policyUpgradeRequired；
  /// - App 组合层先等待 AuthNotifier.logout() 清理登录态；成功完成后才调用本方法
  ///   切到 upgradeDeclinedForSession，让根 DialogRoute 关闭，避免业务页短暂暴露。
  ///
  /// 返回 false 表示当前不是可拒绝的升级状态。调用方必须先核对状态，再执行具有
  /// 外部影响的退出动作；PrivacyConsentHost 已按该顺序统一编排。
  bool declineUpgradeForCurrentSession() {
    if (state.isSaving || !state.shouldShowPolicyUpgrade) return false;
    state = state.copyWith(
      status: PrivacyConsentStatus.upgradeDeclinedForSession,
      clearFailure: true,
    );
    return true;
  }

  /// 撤回隐私同意，供真实项目的“设置/隐私”页面调用。
  ///
  /// 删除成功后立即切回 initialConsentRequired，后续登录请求会再次要求授权。已经
  /// 初始化且厂商不支持反初始化的 SDK 无法由本状态机自动撤销，因此真实项目的
  /// “撤回授权”用例还应同时退出登录，并按各 SDK 文档停止采集或提示重新启动。
  Future<bool> revoke() async {
    if (state.isSaving) return false;
    // 内存状态必须先停止放行，再尝试删除磁盘记录。即使删除失败，本进程也不能
    // 继续把用户当成已同意；页面可以提示重试，原始错误仍交给统一异常观察器。
    state = state.copyWith(
      status: PrivacyConsentStatus.initialConsentRequired,
      clearAcceptedRecord: true,
      isSaving: true,
      clearFailure: true,
    );
    try {
      final removed = await ref
          .read(privacyConsentRepositoryProvider)
          .clearAcceptedPolicyVersion();
      if (!ref.mounted) return false;
      if (!removed) {
        state = state.copyWith(
          isSaving: false,
          failure: PrivacyConsentFailure.revokeFailed,
        );
        return false;
      }
      state = state.copyWith(isSaving: false, clearFailure: true);
      return true;
    } catch (error, stackTrace) {
      FailureObserver.reportIfNeeded(error, stackTrace);
      if (ref.mounted) {
        state = state.copyWith(
          isSaving: false,
          failure: PrivacyConsentFailure.revokeFailed,
        );
      }
      return false;
    }
  }
}

/// 整个进程共享一份隐私同意状态；退出登录不会销毁或清除它。
final privacyConsentProvider =
    NotifierProvider<PrivacyConsentNotifier, PrivacyConsentState>(
      PrivacyConsentNotifier.new,
    );
