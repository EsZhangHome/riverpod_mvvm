import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import 'package:riverpod_mvvm/features/auth/auth_composition.dart';
import 'package:riverpod_mvvm/features/auth/login/application/sign_in_use_case.dart';
import 'package:riverpod_mvvm/features/auth/login/model/login_request.dart';
import 'package:riverpod_mvvm/features/auth/login/view/login_page.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';
import 'package:riverpod_mvvm/l10n/app_localizations.dart';

const _policy = PrivacyPolicyConfig(
  version: '2026.07.01',
  documentVersion: '2026.07.01-doc.3',
  url: 'https://example.test/privacy',
  userAgreementDocumentVersion: '2026.07.01-agreement.2',
  userAgreementUrl: 'https://example.test/user-agreement',
);

final class _MemoryPrivacyConsentRepository
    implements PrivacyConsentRepository {
  _MemoryPrivacyConsentRepository({
    this.acceptedVersion,
    this.saveSucceeds = true,
    this.clearSucceeds = true,
  });

  String? acceptedVersion;
  PrivacyConsentRecord? lastSavedRecord;
  bool saveSucceeds;
  bool clearSucceeds;

  @override
  PrivacyConsentRecord? readAcceptedPolicyRecord() => acceptedVersion == null
      ? null
      : PrivacyConsentRecord.fromLegacyVersion(acceptedVersion!);

  @override
  Future<bool> saveAcceptedPolicyRecord(PrivacyConsentRecord record) async {
    if (!saveSucceeds) return false;
    lastSavedRecord = record;
    acceptedVersion = record.consentVersion;
    return true;
  }

  @override
  Future<bool> clearAcceptedPolicyVersion() async {
    if (!clearSucceeds) return false;
    acceptedVersion = null;
    return true;
  }
}

final class _RecordingPolicyLauncher implements PrivacyPolicyLauncher {
  Uri? openedUri;
  bool succeeds = true;

  @override
  Future<bool> open(Uri uri) async {
    openedUri = uri;
    return succeeds;
  }
}

final class _RecordingSignIn implements SignIn {
  LoginRequest? request;
  var callCount = 0;

  @override
  Future<SignInResult> call(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  }) async {
    callCount++;
    this.request = request;
    return SignInResult.authenticated;
  }
}

ProviderContainer _container(_MemoryPrivacyConsentRepository repository) {
  return ProviderContainer(
    overrides: [
      privacyPolicyConfigProvider.overrideWithValue(_policy),
      privacyConsentRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

Widget _dialogTestApp({
  required _MemoryPrivacyConsentRepository repository,
  required ValueChanged<bool> onResult,
  PrivacyPolicyLauncher? policyLauncher,
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return ProviderScope(
    overrides: [
      privacyPolicyConfigProvider.overrideWithValue(_policy),
      privacyConsentRepositoryProvider.overrideWithValue(repository),
      if (policyLauncher != null)
        privacyPolicyLauncherProvider.overrideWithValue(policyLauncher),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => PrivacyConsentHost(
        navigatorKey: navigatorKey,
        showInitialConsent: false,
        onDeclineUpgrade: () async {},
        child: child ?? const SizedBox.shrink(),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('request.consent'),
            onPressed: () async {
              onResult(
                await requestPrivacyConsentBeforeLogin(
                  context,
                  agreementSelected: false,
                ),
              );
            },
            child: const Text('request'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('没有历史版本时恢复为首次登录授权状态', () {
    final container = _container(_MemoryPrivacyConsentRepository());
    addTearDown(container.dispose);

    final state = container.read(privacyConsentProvider);

    expect(state.status, PrivacyConsentStatus.initialConsentRequired);
    expect(state.hasAcceptedCurrentPolicy, isFalse);
  });

  test('旧版本识别为政策升级，当前版本直接放行', () {
    final oldContainer = _container(
      _MemoryPrivacyConsentRepository(acceptedVersion: '2025.01.01'),
    );
    final currentContainer = _container(
      _MemoryPrivacyConsentRepository(acceptedVersion: _policy.version),
    );
    addTearDown(oldContainer.dispose);
    addTearDown(currentContainer.dispose);

    expect(
      oldContainer.read(privacyConsentProvider).status,
      PrivacyConsentStatus.policyUpgradeRequired,
    );
    expect(
      currentContainer.read(privacyConsentProvider).hasAcceptedCurrentPolicy,
      isTrue,
    );
  });

  test('同意版本保存成功后才发布 granted', () async {
    final repository = _MemoryPrivacyConsentRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final accepted = await container
        .read(privacyConsentProvider.notifier)
        .acceptCurrentPolicy();

    expect(accepted, isTrue);
    expect(repository.acceptedVersion, _policy.version);
    expect(
      repository.lastSavedRecord?.documentVersion,
      _policy.documentVersion,
    );
    expect(
      repository.lastSavedRecord?.userAgreementDocumentVersion,
      _policy.userAgreementDocumentVersion,
    );
    expect(repository.lastSavedRecord?.acceptedAtUtc?.isUtc, isTrue);
    expect(
      container.read(privacyConsentProvider).hasAcceptedCurrentPolicy,
      isTrue,
    );
  });

  test('只修改政策文档版本不会强制用户重新同意', () {
    final repository = _MemoryPrivacyConsentRepository(
      acceptedVersion: _policy.version,
    );
    final container = ProviderContainer(
      overrides: [
        privacyPolicyConfigProvider.overrideWithValue(
          const PrivacyPolicyConfig(
            version: '2026.07.01',
            documentVersion: '2026.07.02-doc.1',
            url: 'https://example.test/privacy',
          ),
        ),
        privacyConsentRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(privacyConsentProvider).hasAcceptedCurrentPolicy,
      isTrue,
    );
  });

  test('保存失败时保持首次同意状态', () async {
    final repository = _MemoryPrivacyConsentRepository(saveSucceeds: false);
    final container = _container(repository);
    addTearDown(container.dispose);

    final accepted = await container
        .read(privacyConsentProvider.notifier)
        .acceptCurrentPolicy();
    final state = container.read(privacyConsentProvider);

    expect(accepted, isFalse);
    expect(state.status, PrivacyConsentStatus.initialConsentRequired);
    expect(state.failure, PrivacyConsentFailure.persistFailed);
  });

  test('撤回失败时当前进程仍立即停止放行', () async {
    final repository = _MemoryPrivacyConsentRepository(
      acceptedVersion: _policy.version,
      clearSucceeds: false,
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final revoked = await container
        .read(privacyConsentProvider.notifier)
        .revoke();
    final state = container.read(privacyConsentProvider);

    expect(revoked, isFalse);
    expect(state.hasAcceptedCurrentPolicy, isFalse);
    expect(state.failure, PrivacyConsentFailure.revokeFailed);
  });

  testWidgets('PrivacyConsentGate 只准备会话，弹窗职责留给 MyApp Host', (tester) async {
    final repository = _MemoryPrivacyConsentRepository();
    var preparationCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_policy),
          privacyConsentRepositoryProvider.overrideWithValue(repository),
        ],
        child: PrivacyConsentGate(
          onPrepareInitialLogin: () async => preparationCount++,
          child: const MaterialApp(
            home: Scaffold(
              body: Text('login page', key: ValueKey('login.page')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(preparationCount, 1);
    expect(find.byKey(const ValueKey('login.page')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
    expect(repository.acceptedVersion, isNull);
  });

  testWidgets('首次登录准备失败时阻止恢复旧会话并允许重试', (tester) async {
    final repository = _MemoryPrivacyConsentRepository();
    var attempt = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_policy),
          privacyConsentRepositoryProvider.overrideWithValue(repository),
        ],
        child: PrivacyConsentGate(
          onPrepareInitialLogin: () async {
            attempt++;
            if (attempt == 1) throw StateError('clear failed');
          },
          child: const MaterialApp(
            home: Scaffold(body: Text('login', key: ValueKey('login.page'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('privacy.preparationError')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('login.page')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('privacy.preparationRetry')));
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.byKey(const ValueKey('login.page')), findsOneWidget);
  });

  testWidgets('登录页请求的协议弹窗拒绝后会 dismiss 并停留登录页', (tester) async {
    final repository = _MemoryPrivacyConsentRepository();
    bool? result;
    await tester.pumpWidget(
      _dialogTestApp(
        repository: repository,
        onResult: (value) => result = value,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('request.consent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('privacy.decline')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(repository.acceptedVersion, isNull);
    expect(find.byKey(const ValueKey('request.consent')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
  });

  testWidgets('登录页请求的协议弹窗同意后会保存版本并继续', (tester) async {
    final repository = _MemoryPrivacyConsentRepository();
    bool? result;
    await tester.pumpWidget(
      _dialogTestApp(
        repository: repository,
        onResult: (value) => result = value,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('request.consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('privacy.accept')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(repository.acceptedVersion, _policy.version);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
  });

  testWidgets('未勾选时点击登录，已填写凭据在同意后原样提交', (tester) async {
    final repository = _MemoryPrivacyConsentRepository();
    final signIn = _RecordingSignIn();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_policy),
          privacyConsentRepositoryProvider.overrideWithValue(repository),
          signInProvider.overrideWithValue(signIn),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => PrivacyConsentHost(
            navigatorKey: navigatorKey,
            showInitialConsent: false,
            onDeclineUpgrade: () async {},
            child: child ?? const SizedBox.shrink(),
          ),
          home: const LoginPage(beforeLogin: requestPrivacyConsentBeforeLogin),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('login.account')),
      ' user@example.test ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login.password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('login.submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
    expect(signIn.callCount, 0);

    await tester.tap(find.byKey(const ValueKey('privacy.accept')));
    await tester.pumpAndSettle();

    expect(signIn.callCount, 1);
    expect(signIn.request?.account, 'user@example.test');
    expect(signIn.request?.password, 'secret');
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('login.agreementCheckbox')),
          )
          .value,
      isTrue,
    );
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
  });

  testWidgets('未勾选时拒绝协议会保持未选中且不发送登录请求', (tester) async {
    final repository = _MemoryPrivacyConsentRepository();
    final signIn = _RecordingSignIn();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_policy),
          privacyConsentRepositoryProvider.overrideWithValue(repository),
          signInProvider.overrideWithValue(signIn),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => PrivacyConsentHost(
            navigatorKey: navigatorKey,
            showInitialConsent: false,
            onDeclineUpgrade: () async {},
            child: child ?? const SizedBox.shrink(),
          ),
          home: const LoginPage(beforeLogin: requestPrivacyConsentBeforeLogin),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('login.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('privacy.decline')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('login.agreementCheckbox')),
          )
          .value,
      isFalse,
    );
    expect(signIn.callCount, 0);
    expect(repository.acceptedVersion, isNull);
  });

  testWidgets('登录前同意保存失败时弹窗保留并显示错误', (tester) async {
    final repository = _MemoryPrivacyConsentRepository(saveSucceeds: false);
    bool? result;
    await tester.pumpWidget(
      _dialogTestApp(
        repository: repository,
        onResult: (value) => result = value,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('request.consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('privacy.accept')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byKey(const ValueKey('privacy.saveError')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
  });

  testWidgets('完整隐私政策由可替换 Launcher 打开且不会叠加第二层 Dialog', (tester) async {
    final repository = _MemoryPrivacyConsentRepository();
    final launcher = _RecordingPolicyLauncher();
    await tester.pumpWidget(
      _dialogTestApp(
        repository: repository,
        policyLauncher: launcher,
        onResult: (_) {},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('request.consent')));
    await tester.pumpAndSettle();
    final openButton = find.byKey(const ValueKey('privacy.viewPolicy'));
    await tester.ensureVisible(openButton);
    await tester.tap(openButton);
    await tester.pumpAndSettle();

    expect(launcher.openedUri, Uri.parse(_policy.url));

    final userAgreementButton = find.byKey(
      const ValueKey('privacy.viewUserAgreement'),
    );
    await tester.ensureVisible(userAgreementButton);
    await tester.tap(userAgreementButton);
    await tester.pumpAndSettle();
    expect(launcher.openedUri, Uri.parse(_policy.userAgreementUrl));
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('多个登录入口并发检查时也只创建一个协议弹窗', (tester) async {
    final repository = _MemoryPrivacyConsentRepository();
    final contentKey = GlobalKey();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_policy),
          privacyConsentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => PrivacyConsentHost(
            navigatorKey: navigatorKey,
            showInitialConsent: false,
            onDeclineUpgrade: () async {},
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(body: SizedBox(key: contentKey)),
        ),
      ),
    );

    final context = contentKey.currentContext!;
    final firstRequest = requestPrivacyConsentBeforeLogin(
      context,
      agreementSelected: false,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);

    final secondResult = await requestPrivacyConsentBeforeLogin(
      context,
      agreementSelected: false,
    );
    expect(secondResult, isFalse);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('privacy.decline')));
    await tester.pumpAndSettle();
    expect(await firstRequest, isFalse);
  });

  testWidgets('政策升级弹窗同意后消失且当前业务页面保持挂载', (tester) async {
    final repository = _MemoryPrivacyConsentRepository(
      acceptedVersion: '2025.01.01',
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_policy),
          privacyConsentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => PrivacyConsentHost(
            navigatorKey: navigatorKey,
            showInitialConsent: false,
            onDeclineUpgrade: () async {},
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(
            body: Text('current detail', key: ValueKey('business.current')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('business.current')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('privacy.accept')));
    await tester.pumpAndSettle();

    expect(repository.acceptedVersion, _policy.version);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
    expect(find.byKey(const ValueKey('business.current')), findsOneWidget);
  });

  testWidgets('政策升级弹窗拒绝后退出登录且本次进程不重复弹出', (tester) async {
    final repository = _MemoryPrivacyConsentRepository(
      acceptedVersion: '2025.01.01',
    );
    var logoutCount = 0;
    final logoutCompleter = Completer<void>();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_policy),
          privacyConsentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => PrivacyConsentHost(
            navigatorKey: navigatorKey,
            showInitialConsent: false,
            onDeclineUpgrade: () {
              logoutCount++;
              return logoutCompleter.future;
            },
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('current page')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final declineButton = find.byKey(const ValueKey('privacy.decline'));
    await tester.ensureVisible(declineButton);
    await tester.tap(declineButton);
    await tester.pump();

    expect(logoutCount, 1);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(declineButton).onPressed,
      isNull,
      reason: '会话清理完成前必须保留遮罩并禁用重复拒绝',
    );

    logoutCompleter.complete();
    await tester.pumpAndSettle();

    expect(repository.acceptedVersion, '2025.01.01');
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
  });
}
