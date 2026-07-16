import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env_config.dart';
import '../../core/providers/service_providers.dart';
import 'model/privacy_policy_config.dart';
import 'repository/privacy_consent_repository.dart';
import 'repository/privacy_policy_launcher.dart';

/// 当前构建的隐私政策配置注入点。
///
/// 默认读取 dart-define；Widget/单元测试可以 override 为固定版本，不需要重新编译。
final privacyPolicyConfigProvider = Provider<PrivacyPolicyConfig>((ref) {
  return const PrivacyPolicyConfig(
    version: EnvConfig.privacyPolicyVersion,
    documentVersion: EnvConfig.privacyPolicyDocumentVersion,
    url: EnvConfig.privacyPolicyUrl,
    userAgreementDocumentVersion: EnvConfig.userAgreementDocumentVersion,
    userAgreementUrl: EnvConfig.userAgreementUrl,
  );
});

/// 生成同意时间的可替换时钟。
///
/// 业务代码不直接散落 `DateTime.now()`：单元测试可以 override 成固定时间，审计记录
/// 也统一使用 UTC。Provider 返回函数而不是创建 Timer，不会产生后台任务。
final privacyConsentClockProvider = Provider<DateTime Function()>((ref) {
  return () => DateTime.now().toUtc();
});

/// 隐私同意 Repository 注入点。
///
/// 它依赖可替换的 PreferencesStore，而不是直接调用 SharedPreferences 插件。
final privacyConsentRepositoryProvider = Provider<PrivacyConsentRepository>((
  ref,
) {
  return LocalPrivacyConsentRepository(ref.watch(preferencesStoreProvider));
});

/// 打开完整隐私政策的系统能力注入点。
///
/// 默认交给系统浏览器，测试可以替换为内存 Fake；Dialog 因此不直接依赖平台插件，
/// 也不需要在底座中引入更重的 WebView、Cookie 和网页导航生命周期。
final privacyPolicyLauncherProvider = Provider<PrivacyPolicyLauncher>((ref) {
  return const ExternalPrivacyPolicyLauncher();
});
