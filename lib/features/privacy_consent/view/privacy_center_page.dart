import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/ui/app_toast.dart';
import '../model/privacy_consent_state.dart';
import '../privacy_consent_providers.dart';
import '../view_model/privacy_consent_view_model.dart';
import 'privacy_disclosure_summary.dart';

/// 撤回当前隐私授权并清理登录会话的应用层回调。
///
/// Privacy Feature 只知道授权记录，不应该反向依赖 Auth Feature。因此页面通过这个
/// 函数把“撤回后退出登录”的跨模块编排交给 MyApp，返回 true 才表示两步都成功。
typedef RevokePrivacyConsent = Future<bool> Function();

/// 用户可以随时打开的隐私中心。
///
/// 与首次授权 Dialog 的职责不同：
/// - Dialog 要求用户对当前版本作出明确选择；
/// - 本页面只展示当前政策、历史同意记录和可执行的撤回入口；
/// - 页面不维护第二份勾选状态，所有事实都来自 privacyConsentProvider。
///
/// 它是公开页面，未登录用户也可以阅读协议。真实项目通常在“设置/关于”中跳转到
/// RoutePaths.privacyCenter，不要复制本页面再保存一套布尔值。
final class PrivacyCenterPage extends ConsumerStatefulWidget {
  const PrivacyCenterPage({
    super.key,
    this.onRevokeConsent,
    this.onRevokeCompleted,
  });

  /// 为空时页面只读；MyApp 默认会注入“撤回授权 + 严格退出登录”的完整动作。
  final RevokePrivacyConsent? onRevokeConsent;

  /// 撤回成功后的导航动作。MyApp 使用项目自己的 loginPath，兼容自定义 SSO 路由。
  final VoidCallback? onRevokeCompleted;

  @override
  ConsumerState<PrivacyCenterPage> createState() => _PrivacyCenterPageState();
}

final class _PrivacyCenterPageState extends ConsumerState<PrivacyCenterPage> {
  bool _isOpeningDocument = false;
  bool _isRevoking = false;
  bool _revokeFailed = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final state = ref.watch(privacyConsentProvider);
    final isBusy = state.isSaving || _isOpeningDocument || _isRevoking;

    return Scaffold(
      appBar: AppBar(title: Text(strings.privacyCenterTitle)),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('privacyCenter.list'),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.privacyCenterIntroduction,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    _ConsentStatusCard(state: state),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              strings.privacyCenterDisclosureTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            const PrivacyDisclosureSummary(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              strings.privacyCenterDocumentsTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(state.policy.url),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              key: const ValueKey(
                                'privacyCenter.openPrivacyPolicy',
                              ),
                              onPressed: isBusy
                                  ? null
                                  : () => unawaited(
                                      _openDocument(state.policy.url),
                                    ),
                              icon: const Icon(Icons.open_in_new),
                              label: Text(strings.viewFullPrivacyPolicy),
                            ),
                            const SizedBox(height: 12),
                            SelectableText(state.policy.userAgreementUrl),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              key: const ValueKey(
                                'privacyCenter.openUserAgreement',
                              ),
                              onPressed: isBusy
                                  ? null
                                  : () => unawaited(
                                      _openDocument(
                                        state.policy.userAgreementUrl,
                                      ),
                                    ),
                              icon: const Icon(Icons.open_in_new),
                              label: Text(strings.viewFullUserAgreement),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.onRevokeConsent != null &&
                        (state.hasAcceptedAnyPolicy ||
                            _isRevoking ||
                            _revokeFailed)) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                strings.privacyCenterRevokeTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(strings.privacyCenterRevokeDescription),
                              if (_revokeFailed) ...[
                                const SizedBox(height: 8),
                                Text(
                                  strings.privacyCenterRevokeFailed,
                                  key: const ValueKey(
                                    'privacyCenter.revokeError',
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'privacyCenter.revokeConsent',
                                ),
                                onPressed: isBusy
                                    ? null
                                    : () => unawaited(_confirmAndRevoke()),
                                icon: _isRevoking
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.no_accounts_outlined),
                                label: Text(strings.privacyCenterRevokeAction),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(String url) async {
    setState(() => _isOpeningDocument = true);
    var opened = false;
    try {
      opened = await ref
          .read(privacyPolicyLauncherProvider)
          .open(Uri.parse(url));
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _isOpeningDocument = false);
    if (!opened) {
      AppToast.showError(
        context,
        AppLocalizations.of(context).privacyPolicyOpenFailed,
      );
    }
  }

  Future<void> _confirmAndRevoke() async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.privacyCenterRevokeConfirmTitle),
        content: Text(strings.privacyCenterRevokeConfirmBody),
        actions: [
          TextButton(
            key: const ValueKey('privacyCenter.revokeCancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            key: const ValueKey('privacyCenter.revokeConfirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.privacyCenterRevokeConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isRevoking = true;
      _revokeFailed = false;
    });
    var succeeded = false;
    try {
      succeeded = await widget.onRevokeConsent!.call();
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) return;
    setState(() {
      _isRevoking = false;
      _revokeFailed = !succeeded;
    });
    if (!succeeded) return;

    AppToast.showSuccess(context, strings.privacyCenterRevokeSucceeded);
    widget.onRevokeCompleted?.call();
  }
}

/// 当前授权事实卡片。
final class _ConsentStatusCard extends StatelessWidget {
  const _ConsentStatusCard({required this.state});

  final PrivacyConsentState state;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final (statusText, statusColor) = switch (state.status) {
      PrivacyConsentStatus.granted => (
        strings.privacyCenterStatusAccepted,
        Theme.of(context).colorScheme.primary,
      ),
      PrivacyConsentStatus.policyUpgradeRequired ||
      PrivacyConsentStatus.upgradeDeclinedForSession => (
        strings.privacyCenterStatusOutdated,
        Theme.of(context).colorScheme.error,
      ),
      _ => (
        strings.privacyCenterStatusNotAccepted,
        Theme.of(context).colorScheme.secondary,
      ),
    };
    final acceptedAt = state.acceptedRecord?.acceptedAtUtc?.toLocal();
    final formattedAcceptedAt = acceptedAt == null
        ? strings.privacyCenterAcceptedAtUnknown
        : '${MaterialLocalizations.of(context).formatFullDate(acceptedAt)} '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(acceptedAt))}';

    return Card(
      key: const ValueKey('privacyCenter.statusCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.privacyCenterStatusTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              key: const ValueKey('privacyCenter.status'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: statusColor),
            ),
            const SizedBox(height: 12),
            Text(strings.privacyConsentVersion(state.policy.version)),
            Text(strings.privacyDocumentVersion(state.policy.documentVersion)),
            Text(
              strings.userAgreementDocumentVersion(
                state.policy.userAgreementDocumentVersion,
              ),
            ),
            if (state.hasAcceptedAnyPolicy) ...[
              const SizedBox(height: 8),
              Text(
                strings.privacyCenterAcceptedVersion(
                  state.acceptedRecord!.consentVersion,
                ),
              ),
              Text(strings.privacyCenterAcceptedAt(formattedAcceptedAt)),
            ],
          ],
        ),
      ),
    );
  }
}
