import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../model/privacy_consent_state.dart';

/// 首次授权与政策升级共同使用的隐私政策弹窗内容。
///
/// 两种场景只在标题、说明和拒绝后的动作上不同，政策版本、保存错误、按钮禁用等
/// 视觉规则应保持一致。抽出这个 Widget 可以避免两套弹窗以后逐渐出现不同样式。
final class PrivacyPolicyDialog extends StatefulWidget {
  const PrivacyPolicyDialog({
    super.key,
    required this.state,
    required this.isBusy,
    required this.declineActionFailed,
    required this.title,
    required this.introduction,
    required this.agreeLabel,
    required this.declineLabel,
    required this.onOpenPolicy,
    required this.onOpenUserAgreement,
    required this.onAgree,
    required this.onDecline,
  });

  /// ViewModel 当前快照，用于显示版本、保存进度和稳定错误类型。
  final PrivacyConsentState state;

  /// 保存同意或退出登录期间为 true，所有操作统一禁用，避免竞态。
  final bool isBusy;

  /// 拒绝升级后的退出动作是否失败；失败时 Dialog 保留并显示稳定提示。
  final bool declineActionFailed;

  /// 当前场景的标题：首次授权与政策升级使用不同文案。
  final String title;

  /// 告诉用户为什么现在需要选择，以及拒绝后会发生什么。
  final String introduction;

  /// 同意按钮文字。
  final String agreeLabel;

  /// 拒绝按钮文字。首次登录场景通常写“不同意”，升级场景写“不同意并退出登录”。
  final String declineLabel;

  /// 打开经过环境校验的完整隐私政策，true 表示系统已成功接管。
  final Future<bool> Function() onOpenPolicy;

  /// 打开经过环境校验的完整用户协议，true 表示系统已成功接管。
  final Future<bool> Function() onOpenUserAgreement;

  /// 同意命令。持久化期间由 [state.isSaving] 自动禁用按钮。
  final VoidCallback onAgree;

  /// 拒绝命令，由外层场景决定是关闭弹窗并保留登录页，还是退出当前登录会话。
  final VoidCallback onDecline;

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();
}

final class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog> {
  bool _isOpeningDocument = false;
  bool _openDocumentFailed = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Dialog(
      key: const ValueKey('privacy.dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 说明正文可以滚动，但同意/拒绝按钮固定在弹窗底部。小屏或系统字体
              // 放大时，用户不需要先把整个弹窗滚到底才能找到关键操作。
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Icon(Icons.privacy_tip_outlined, size: 48),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.introduction),
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.privacyConsentVersion(
                                  widget.state.policy.version,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                strings.privacyDocumentVersion(
                                  widget.state.policy.documentVersion,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                strings.userAgreementDocumentVersion(
                                  widget
                                      .state
                                      .policy
                                      .userAgreementDocumentVersion,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(strings.privacyPolicyAddress),
                              const SizedBox(height: 4),
                              SelectableText(widget.state.policy.url),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                            key: const ValueKey('privacy.viewPolicy'),
                            onPressed: widget.isBusy || _isOpeningDocument
                                ? null
                                : () => _openDocument(widget.onOpenPolicy),
                            child: Text(strings.viewFullPrivacyPolicy),
                          ),
                          TextButton(
                            key: const ValueKey('privacy.viewUserAgreement'),
                            onPressed: widget.isBusy || _isOpeningDocument
                                ? null
                                : () =>
                                      _openDocument(widget.onOpenUserAgreement),
                            child: Text(strings.viewFullUserAgreement),
                          ),
                          if (_isOpeningDocument)
                            const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_openDocumentFailed)
                        Text(
                          strings.privacyPolicyOpenFailed,
                          key: const ValueKey('privacy.openPolicyError'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.state.failure == PrivacyConsentFailure.persistFailed ||
                  widget.declineActionFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    widget.declineActionFailed
                        ? strings.privacyLogoutFailed
                        : strings.privacyConsentSaveFailed,
                    key: const ValueKey('privacy.saveError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton(
                key: const ValueKey('privacy.accept'),
                onPressed: widget.isBusy ? null : widget.onAgree,
                child: widget.isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.agreeLabel),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('privacy.decline'),
                onPressed: widget.isBusy ? null : widget.onDecline,
                child: Text(widget.declineLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDocument(Future<bool> Function() open) async {
    setState(() {
      _isOpeningDocument = true;
      _openDocumentFailed = false;
    });
    var opened = false;
    try {
      opened = await open();
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _isOpeningDocument = false;
      _openDocumentFailed = !opened;
    });
  }
}

/// 显著告知中的一项摘要。
///
/// 完整法律文本仍在外部政策页；这里用短句告诉用户最关键的处理范围，避免只放一个
/// “请阅读隐私政策”链接。真实项目应结合业务修改对应本地化文案和完整政策。
final class _DisclosureItem extends StatelessWidget {
  const _DisclosureItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
