import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/app/app.dart';
import 'package:riverpod_mvvm/app/bootstrap/app_warmup.dart';
import 'package:riverpod_mvvm/app/navigation/app_route_bundle.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';

const _policy = PrivacyPolicyConfig(
  version: 'consent-2',
  documentVersion: 'privacy-doc-3',
  url: 'https://example.test/privacy',
  userAgreementDocumentVersion: 'agreement-doc-4',
  userAgreementUrl: 'https://example.test/agreement',
);

final class _MemoryPrivacyRepository implements PrivacyConsentRepository {
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

final class _MemorySessionStore implements SessionStore {
  AuthSession? session = const AuthSession(
    token: 'test-token',
    user: UserModel(id: '1', name: 'Tester', email: 'tester@example.test'),
  );
  int clearCount = 0;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async {
    clearCount++;
    session = null;
  }
}

void main() {
  testWidgets('隐私中心撤回授权后清理会话并回到登录页', (tester) async {
    final privacyRepository = _MemoryPrivacyRepository();
    final sessionStore = _MemorySessionStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_policy),
          privacyConsentRepositoryProvider.overrideWithValue(privacyRepository),
          sessionStoreProvider.overrideWithValue(sessionStore),
          appWarmupTasksProvider.overrideWithValue(const []),
        ],
        child: MyApp(
          routeBundle: AppRouteBundle(
            authenticatedHome: '/home',
            loginBuilder: (context, state) => const Scaffold(
              body: Text('login', key: ValueKey('route.login')),
            ),
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => Scaffold(
                  body: TextButton(
                    key: const ValueKey('open.privacyCenter'),
                    onPressed: () => context.push(RoutePaths.privacyCenter),
                    child: const Text('privacy center'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open.privacyCenter')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open.privacyCenter')));
    await tester.pumpAndSettle();

    final revoke = find.byKey(const ValueKey('privacyCenter.revokeConsent'));
    await tester.ensureVisible(revoke);
    await tester.pumpAndSettle();
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('privacyCenter.revokeConfirm')));
    await tester.pumpAndSettle();

    expect(privacyRepository.record, isNull);
    expect(sessionStore.session, isNull);
    expect(sessionStore.clearCount, 1);
    expect(find.byKey(const ValueKey('route.login')), findsOneWidget);
    // 撤回后回到未授权状态，因此登录页上方会重新出现唯一的首次授权 Dialog。
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
  });
}
