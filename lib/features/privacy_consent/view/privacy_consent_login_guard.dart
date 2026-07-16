import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../privacy_consent_providers.dart';
import '../view_model/privacy_consent_view_model.dart';
import '../view_model/privacy_prompt_coordinator.dart';

/// 登录命令真正发出前请求隐私授权。
///
/// 本函数故意不调用 showDialog：它只通过当前 ProviderScope 找到 App 级协调器，然后
/// 等待唯一 PrivacyConsentHost 返回结果。默认账号密码登录、SSO 和其他自定义登录
/// 入口都可以复用它，不会各自维护一套 Dialog 与防重复变量。
///
/// [agreementSelected] 是登录页复选框的当前值：
/// - true：用户已在本页明确选择协议。若磁盘还没有当前版本记录，就在这里保存；
/// - false：要求根 Host 弹出协议说明，等待用户明确同意或拒绝。
///
/// 返回 true 只表示协议门禁已经通过。账号、密码等业务字段应由登录 ViewModel
/// 继续校验；返回 false 时调用方必须终止本次登录请求。
Future<bool> requestPrivacyConsentBeforeLogin(
  BuildContext context, {
  required bool agreementSelected,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final consent = container.read(privacyConsentProvider);

  if (agreementSelected) {
    if (consent.hasAcceptedCurrentPolicy) return Future<bool>.value(true);

    // 升级状态由全局 Host 正在处理。这里不能再保存或再开弹窗，否则业务页可能
    // 越过升级确认，或者出现两层协议 Dialog。
    if (consent.shouldShowPolicyUpgrade) return Future<bool>.value(false);

    // 勾选本身就是用户在登录页做出的明确同意动作。只有保存成功才能放行登录；
    // 保存失败时 Dialog/页面仍保持可操作，绝不会乐观地把失败当作已授权。
    return container
        .read(privacyConsentProvider.notifier)
        .acceptCurrentPolicy();
  }

  return container
      .read(privacyPromptCoordinatorProvider.notifier)
      .requestBeforeLogin();
}

/// 从登录页打开完整隐私协议。
Future<bool> openPrivacyPolicyDocument(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final policy = container.read(privacyPolicyConfigProvider);
  return container
      .read(privacyPolicyLauncherProvider)
      .open(Uri.parse(policy.url));
}

/// 从登录页打开完整用户协议。
Future<bool> openUserAgreementDocument(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final policy = container.read(privacyPolicyConfigProvider);
  return container
      .read(privacyPolicyLauncherProvider)
      .open(Uri.parse(policy.userAgreementUrl));
}
