import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';
import 'package:riverpod_mvvm/l10n/app_localizations.dart';

const _policy = PrivacyPolicyConfig(
  version: 'consent-2',
  documentVersion: 'privacy-doc-3',
  url: 'https://example.test/privacy',
  userAgreementDocumentVersion: 'agreement-doc-4',
  userAgreementUrl: 'https://example.test/agreement',
);

final class _Repository implements PrivacyConsentRepository {
  PrivacyConsentRecord? record = PrivacyConsentRecord(
    consentVersion: _policy.version,
    documentVersion: _policy.documentVersion,
    userAgreementDocumentVersion: _policy.userAgreementDocumentVersion,
    acceptedAtUtc: DateTime.utc(2026, 7, 17, 8, 30),
  );

  @override
  PrivacyConsentRecord? readAcceptedPolicyRecord() => record;

  @override
  Future<bool> saveAcceptedPolicyRecord(PrivacyConsentRecord record) async {
    this.record = record;
    return true;
  }

  @override
  Future<bool> clearAcceptedPolicyVersion() async {
    record = null;
    return true;
  }
}

final class _Launcher implements PrivacyPolicyLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

Widget _testApp({
  required _Repository repository,
  required _Launcher launcher,
  RevokePrivacyConsent? onRevoke,
  VoidCallback? onRevokeCompleted,
}) {
  return ProviderScope(
    overrides: [
      privacyPolicyConfigProvider.overrideWithValue(_policy),
      privacyConsentRepositoryProvider.overrideWithValue(repository),
      privacyPolicyLauncherProvider.overrideWithValue(launcher),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PrivacyCenterPage(
        onRevokeConsent: onRevoke,
        onRevokeCompleted: onRevokeCompleted,
      ),
    ),
  );
}

void main() {
  testWidgets('隐私中心展示当前授权事实并打开两份完整协议', (tester) async {
    final repository = _Repository();
    final launcher = _Launcher();

    await tester.pumpWidget(
      _testApp(repository: repository, launcher: launcher),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('privacyCenter.statusCard')),
      findsOneWidget,
    );
    expect(find.text('已同意当前版本'), findsOneWidget);

    final privacyButton = find.byKey(
      const ValueKey('privacyCenter.openPrivacyPolicy'),
    );
    await tester.ensureVisible(privacyButton);
    await tester.pumpAndSettle();
    await tester.tap(privacyButton);
    await tester.pump();

    final agreementButton = find.byKey(
      const ValueKey('privacyCenter.openUserAgreement'),
    );
    await tester.ensureVisible(agreementButton);
    await tester.pumpAndSettle();
    await tester.tap(agreementButton);
    await tester.pump();

    expect(launcher.opened, [
      Uri.parse(_policy.url),
      Uri.parse(_policy.userAgreementUrl),
    ]);
  });

  testWidgets('撤回前二次确认，成功后执行应用层完成动作', (tester) async {
    final repository = _Repository();
    final launcher = _Launcher();
    var revokeCalls = 0;
    var completedCalls = 0;

    await tester.pumpWidget(
      _testApp(
        repository: repository,
        launcher: launcher,
        onRevoke: () async {
          revokeCalls++;
          return true;
        },
        onRevokeCompleted: () => completedCalls++,
      ),
    );
    await tester.pumpAndSettle();

    final revokeButton = find.byKey(
      const ValueKey('privacyCenter.revokeConsent'),
    );
    await tester.ensureVisible(revokeButton);
    await tester.pumpAndSettle();
    await tester.tap(revokeButton);
    await tester.pumpAndSettle();
    expect(revokeCalls, 0);

    await tester.tap(find.byKey(const ValueKey('privacyCenter.revokeConfirm')));
    await tester.pump();

    expect(revokeCalls, 1);
    expect(completedCalls, 1);
  });
}
