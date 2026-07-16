// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/app/app.dart';
import 'package:riverpod_mvvm/app/navigation/app_route_bundle.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';
import 'package:riverpod_mvvm/l10n/app_localizations.dart';
import 'package:riverpod_mvvm/shared/ui/error_view.dart';

const _testHomePath = '/test-home';
const _testPolicy = PrivacyPolicyConfig(
  version: 'widget-test-v1',
  url: 'https://example.test/privacy',
);

/// 只用于验证“App 运行中政策版本升级”的可变配置源。
final class _TestPolicyNotifier extends Notifier<PrivacyPolicyConfig> {
  @override
  PrivacyPolicyConfig build() => _testPolicy;

  void upgrade() {
    state = const PrivacyPolicyConfig(
      version: 'widget-test-v2',
      url: 'https://example.test/privacy-v2',
    );
  }
}

final _testPolicyProvider =
    NotifierProvider<_TestPolicyNotifier, PrivacyPolicyConfig>(
      _TestPolicyNotifier.new,
    );

AppRouteBundle _createTestRouteBundle() {
  return AppRouteBundle(
    authenticatedHome: _testHomePath,
    routes: [
      GoRoute(
        path: _testHomePath,
        builder: (context, state) => const _TestHomePage(),
      ),
    ],
  );
}

/// 测试自己的登录后页面，不依赖可删除 Starter 组件。
///
/// 这样真实项目删除 lib/app/starter 后，通用 MyApp/Auth 测试仍能原样运行。
class _TestHomePage extends ConsumerWidget {
  const _TestHomePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: TextButton(
        key: const ValueKey('logout'),
        onPressed: () => ref.read(authProvider.notifier).logout(),
        child: const Text('test home'),
      ),
    );
  }
}

final class _MemorySessionStore implements SessionStore {
  _MemorySessionStore(this.session);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

final class _MemoryPrivacyConsentRepository
    implements PrivacyConsentRepository {
  _MemoryPrivacyConsentRepository(this.acceptedVersion);

  String? acceptedVersion;

  @override
  PrivacyConsentRecord? readAcceptedPolicyRecord() => acceptedVersion == null
      ? null
      : PrivacyConsentRecord.fromLegacyVersion(acceptedVersion!);

  @override
  Future<bool> saveAcceptedPolicyRecord(PrivacyConsentRecord record) async {
    acceptedVersion = record.consentVersion;
    return true;
  }

  @override
  Future<bool> clearAcceptedPolicyVersion() async {
    acceptedVersion = null;
    return true;
  }
}

Widget _testScope({
  required SessionStore store,
  required Widget child,
  bool hasAcceptedPrivacy = true,
}) {
  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      privacyPolicyConfigProvider.overrideWithValue(_testPolicy),
      privacyConsentRepositoryProvider.overrideWithValue(
        _MemoryPrivacyConsentRepository(
          hasAcceptedPrivacy ? _testPolicy.version : null,
        ),
      ),
    ],
    child: child,
  );
}

void main() {
  testWidgets('app starts at login page when there is no token', (
    tester,
  ) async {
    // Arrange：注入空会话，测试不依赖设备 Keychain/Keystore 插件。
    final store = _MemorySessionStore(null);
    final routeBundle = _createTestRouteBundle();

    // Act：挂载完整 App，ProviderScope、AuthNotifier、GoRouter 都走生产组装路径。
    await tester.pumpWidget(
      _testScope(
        store: store,
        child: MyApp(routeBundle: routeBundle),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login.submit')), findsOneWidget);
    expect(find.text('Riverpod MVVM'), findsOneWidget);

    // authenticatedHome 即使没有重复加入 protectedPaths，也必须被守卫自动拦截。
    tester
        .element(find.byKey(const ValueKey('login.submit')))
        .go(routeBundle.authenticatedHome);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login.submit')), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);

    // 默认 MyApp 只注册底座页面，具体业务路由必须由项目入口显式注入。
  });

  testWidgets(
    'first launch opens consent, accepts silently, then keeps validation intact',
    (tester) async {
      final store = _MemorySessionStore(null);

      await tester.pumpWidget(
        _testScope(
          store: store,
          hasAcceptedPrivacy: false,
          child: MyApp(routeBundle: _createTestRouteBundle()),
        ),
      );
      await tester.pumpAndSettle();

      // 认证恢复确认进入登录页后，首次协议自动覆盖且复选框仍是未选中。
      expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('login.agreementCheckbox')),
            )
            .value,
        isFalse,
      );

      // 自动弹窗同意后仅选中协议。因为它不是登录提交动作，所以不会校验空表单。
      await tester.tap(find.byKey(const ValueKey('privacy.accept')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('login.agreementCheckbox')),
            )
            .value,
        isTrue,
      );

      final loginContext = tester.element(
        find.byKey(const ValueKey('login.submit')),
      );
      expect(
        find.text(AppLocalizations.of(loginContext).enterAccount),
        findsNothing,
      );

      // 用户再次主动点击登录时协议已经选中，此时才执行正常账号密码校验并提示。
      await tester.tap(find.byKey(const ValueKey('login.submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(AppLocalizations.of(loginContext).enterAccount),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ErrorView), findsNothing);
    },
  );

  testWidgets(
    'declining initial consent unchecks and login can request it again',
    (tester) async {
      await tester.pumpWidget(
        _testScope(
          store: _MemorySessionStore(null),
          hasAcceptedPrivacy: false,
          child: MyApp(routeBundle: _createTestRouteBundle()),
        ),
      );
      await tester.pumpAndSettle();

      final checkbox = find.byKey(const ValueKey('login.agreementCheckbox'));
      expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('privacy.decline')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);

      // 本次运行不再自动弹，但未勾选点击登录仍由同一个 Host 再次展示。
      await tester.tap(find.byKey(const ValueKey('login.submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('privacy.decline')));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    },
  );

  testWidgets('policy upgrade clears the login agreement selection', (
    tester,
  ) async {
    final store = _MemorySessionStore(null);
    final privacyRepository = _MemoryPrivacyConsentRepository(
      _testPolicy.version,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          privacyPolicyConfigProvider.overrideWith(
            (ref) => ref.watch(_testPolicyProvider),
          ),
          privacyConsentRepositoryProvider.overrideWithValue(privacyRepository),
        ],
        child: MyApp(routeBundle: _createTestRouteBundle()),
      ),
    );
    await tester.pumpAndSettle();

    final checkbox = find.byKey(const ValueKey('login.agreementCheckbox'));
    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);

    final context = tester.element(checkbox);
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(_testPolicyProvider.notifier).upgrade();
    await tester.pumpAndSettle();

    // 政策一升级，旧选择立即失效；拒绝升级后仍保持未选中并回到登录页。
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    await tester.tap(find.byKey(const ValueKey('privacy.decline')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
  });

  testWidgets('app does not paint login page while restoring saved session', (
    tester,
  ) async {
    // Arrange：准备一份完整会话，模拟上一次已登录。
    final store = _MemorySessionStore(
      const AuthSession(
        token: 'saved_token',
        user: UserModel(id: '1', name: 'Test User', email: 'test@example.com'),
      ),
    );
    final routeBundle = _createTestRouteBundle();

    await tester.pumpWidget(
      _testScope(
        store: store,
        child: MyApp(routeBundle: routeBundle),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('login.submit')), findsNothing);

    await tester.pumpAndSettle();

    // 保存的完整会话会直接进入项目首页，不先闪现登录页。
    expect(find.byType(_TestHomePage), findsOneWidget);
    expect(find.byKey(const ValueKey('login.submit')), findsNothing);

    // 退出只更新 AuthState；通用守卫负责“首页 → 登录”的完整闭环。
    await tester.tap(find.byKey(const ValueKey('logout')));
    await tester.pumpAndSettle();
    expect(store.session, isNull);
    expect(find.byKey(const ValueKey('login.submit')), findsOneWidget);
  });
}

// App 根级 Widget 测试：关注启动期会话恢复和路由守卫，不测试具体业务列表。
