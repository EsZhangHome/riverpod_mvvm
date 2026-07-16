// 隐私同意模块对外门面。App 组合层使用首次会话准备 Gate、登录前授权函数和全局
// 升级 Host；真实项目设置页如需撤回，可读取 privacyConsentProvider.notifier。
// Repository 保持公开，便于测试和项目替换存储。
export 'model/privacy_consent_record.dart';
export 'model/privacy_consent_state.dart';
export 'model/privacy_policy_config.dart';
export 'model/privacy_prompt_state.dart';
export 'privacy_consent_providers.dart';
export 'repository/privacy_consent_repository.dart';
export 'repository/privacy_policy_launcher.dart';
export 'view/privacy_consent_gate.dart';
export 'view/privacy_consent_host.dart';
export 'view/privacy_consent_login_guard.dart';
export 'view_model/privacy_consent_view_model.dart';
export 'view_model/privacy_prompt_coordinator.dart';
