// Demo 专属的隐私政策版本模拟器。
//
// 它只改变“当前构建要求用户同意哪个版本”，不直接控制 Dialog，也不伪造同意状态。
// 底座 PrivacyConsentNotifier 仍会读取历史记录、比较版本并产生正式升级状态。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_mvvm/core/config/env_config.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';

/// 管理 Demo 运行期间的当前政策配置。
///
/// 这里使用 App 级 NotifierProvider，是因为政策版本会影响全局隐私门禁，而不是某个
/// 页面自己的临时 UI。Mine 页面离开后 Provider 仍然存在，全局 Host 才能继续处理
/// 同意或拒绝操作。
final class DemoPrivacyPolicySimulator extends Notifier<PrivacyPolicyConfig> {
  int _upgradeSequence = 0;

  /// 从环境配置恢复默认政策；若上次已经同意 Demo 模拟版本，则恢复该模拟版本。
  ///
  /// 恢复模拟版本是为了避免开发者冷启动后，把上次保存在 Demo 沙箱中的模拟记录
  /// 错误识别成又一次升级。标记只存在于独立 Demo App，不会进入企业底座正式包。
  @override
  PrivacyPolicyConfig build() {
    final basePolicy = _basePolicy;
    try {
      final acceptedRecord = ref
          .watch(privacyConsentRepositoryProvider)
          .readAcceptedPolicyRecord();
      final acceptedVersion = acceptedRecord?.consentVersion;
      final sequence = acceptedVersion == null
          ? null
          : _readSimulationSequence(acceptedVersion);
      if (acceptedRecord != null && sequence != null) {
        _upgradeSequence = sequence;
        return PrivacyPolicyConfig(
          version: acceptedRecord.consentVersion,
          documentVersion: acceptedRecord.documentVersion,
          url: basePolicy.url,
          userAgreementDocumentVersion:
              acceptedRecord.userAgreementDocumentVersion,
          userAgreementUrl: basePolicy.userAgreementUrl,
        );
      }
    } catch (_) {
      // 隐私状态管理器会对 Repository 读取异常执行 fail-closed 并统一上报。模拟器只
      // 回退到环境版本，不能在旁路吞掉异常后自行判定用户已经同意。
    }
    _upgradeSequence = 0;
    return basePolicy;
  }

  /// 发布一个新的模拟授权版本。
  ///
  /// 这里只更新 Provider state。privacyPolicyConfigProvider 的 Demo override 会收到
  /// 新配置，继而让底座 PrivacyConsentNotifier 重新比较历史版本并触发全局弹窗。
  void simulateNextUpgrade() {
    final basePolicy = _basePolicy;
    final nextSequence = ++_upgradeSequence;
    state = PrivacyPolicyConfig(
      version: '${basePolicy.version}-demo-upgrade-$nextSequence',
      documentVersion:
          '${basePolicy.documentVersion}-demo-upgrade-$nextSequence',
      url: basePolicy.url,
      userAgreementDocumentVersion:
          '${basePolicy.userAgreementDocumentVersion}-demo-upgrade-$nextSequence',
      userAgreementUrl: basePolicy.userAgreementUrl,
    );
  }

  /// Demo 的真实环境基线。每次通过 getter 创建，避免 Notifier 因依赖变化重新 build
  /// 时重复给 late final 字段赋值。
  PrivacyPolicyConfig get _basePolicy => const PrivacyPolicyConfig(
    version: EnvConfig.privacyPolicyVersion,
    documentVersion: EnvConfig.privacyPolicyDocumentVersion,
    url: EnvConfig.privacyPolicyUrl,
    userAgreementDocumentVersion: EnvConfig.userAgreementDocumentVersion,
    userAgreementUrl: EnvConfig.userAgreementUrl,
  );

  int? _readSimulationSequence(String version) {
    final prefix = '${_basePolicy.version}-demo-upgrade-';
    if (!version.startsWith(prefix)) return null;
    final sequence = int.tryParse(version.substring(prefix.length));
    return sequence != null && sequence > 0 ? sequence : null;
  }
}

/// Demo 当前政策配置的唯一可变来源。
final demoPrivacyPolicyConfigProvider =
    NotifierProvider<DemoPrivacyPolicySimulator, PrivacyPolicyConfig>(
      DemoPrivacyPolicySimulator.new,
    );
