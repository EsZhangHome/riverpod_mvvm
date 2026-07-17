import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 隐私政策的四项显著告知摘要。
///
/// 首次授权弹窗和“隐私中心”复用同一个 Widget，避免两个页面分别维护文案后逐渐
/// 不一致。这里展示的是帮助用户快速理解的摘要，不能替代完整隐私政策；真实项目
/// 必须结合实际采集信息、系统权限和第三方 SDK 修改对应 ARB 文案。
final class PrivacyDisclosureSummary extends StatelessWidget {
  const PrivacyDisclosureSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Column(
      children: [
        _DisclosureItem(
          icon: Icons.account_circle_outlined,
          title: strings.privacyDisclosureDataTitle,
          body: strings.privacyDisclosureDataBody,
        ),
        _DisclosureItem(
          icon: Icons.fact_check_outlined,
          title: strings.privacyDisclosurePurposeTitle,
          body: strings.privacyDisclosurePurposeBody,
        ),
        _DisclosureItem(
          icon: Icons.extension_outlined,
          title: strings.privacyDisclosureThirdPartyTitle,
          body: strings.privacyDisclosureThirdPartyBody,
        ),
        _DisclosureItem(
          icon: Icons.manage_accounts_outlined,
          title: strings.privacyDisclosureRightsTitle,
          body: strings.privacyDisclosureRightsBody,
          showBottomPadding: false,
        ),
      ],
    );
  }
}

/// 显著告知中的一项摘要。
final class _DisclosureItem extends StatelessWidget {
  const _DisclosureItem({
    required this.icon,
    required this.title,
    required this.body,
    this.showBottomPadding = true,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool showBottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: showBottomPadding ? 10 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
