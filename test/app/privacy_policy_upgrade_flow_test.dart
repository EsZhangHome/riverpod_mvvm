import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/app/app.dart';
import 'package:riverpod_mvvm/app/bootstrap/app_bootstrap.dart';
import 'package:riverpod_mvvm/app/bootstrap/app_warmup.dart';
import 'package:riverpod_mvvm/app/bootstrap/bootstrap_gate.dart';
import 'package:riverpod_mvvm/app/navigation/app_route_bundle.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';

const _currentPolicy = PrivacyPolicyConfig(
  version: '2026.07.01',
  url: 'https://example.test/privacy',
);

/// 跨模块验收用例：隐私 Feature 只发出选择结果，MyApp 负责连接 Auth 和 GoRouter。
/// Fake Store 让测试从“已经登录的详情页”开始，不访问真实安全存储。
final class _MemorySessionStore implements SessionStore {
  _MemorySessionStore(this.session);

  AuthSession? session;
  var clearCount = 0;

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

final class _OldPrivacyRepository implements PrivacyConsentRepository {
  String? acceptedVersion = '2025.01.01';

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

final class _InitialPrivacyRepository implements PrivacyConsentRepository {
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

void main() {
  testWidgets('首次启动先清除残留安全会话并直接进入登录页', (tester) async {
    final sessionStore = _MemorySessionStore(
      const AuthSession(
        token: 'stale-token',
        user: UserModel(id: '1', name: 'Tester', email: 't@example.test'),
      ),
    );
    final privacyRepository = _InitialPrivacyRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_currentPolicy),
          privacyConsentRepositoryProvider.overrideWithValue(privacyRepository),
          sessionStoreProvider.overrideWithValue(sessionStore),
          appWarmupTasksProvider.overrideWithValue(const []),
        ],
        child: BootstrapGate(
          bootstrap: AppBootstrap(
            validateConfiguration: () {},
            initializeStorage: () async {},
          ),
          routeBundle: AppRouteBundle(
            authenticatedHome: '/home',
            loginBuilder: (context, state) => const Scaffold(
              body: Text('login page', key: ValueKey('route.login')),
            ),
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const Scaffold(
                  body: Text('home page', key: ValueKey('route.home')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 首次打开先清除可能残留在安全存储里的会话，进入登录页后由 App Host 自动
    // 显示一次协议。即使项目替换了默认登录页，首次门禁仍不会被绕过。
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('route.login')), findsOneWidget);
    expect(find.byKey(const ValueKey('route.home')), findsNothing);

    expect(sessionStore.clearCount, 1);
    expect(sessionStore.session, isNull);
    expect(privacyRepository.acceptedVersion, isNull);
    expect(find.byKey(const ValueKey('route.home')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('privacy.decline')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
    expect(find.byKey(const ValueKey('route.login')), findsOneWidget);
    expect(privacyRepository.acceptedVersion, isNull);
  });

  testWidgets('首次登录遇到政策升级时只显示一个升级弹窗', (tester) async {
    final sessionStore = _MemorySessionStore(null);
    final privacyRepository = _OldPrivacyRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_currentPolicy),
          privacyConsentRepositoryProvider.overrideWithValue(privacyRepository),
          sessionStoreProvider.overrideWithValue(sessionStore),
          appWarmupTasksProvider.overrideWithValue(const []),
        ],
        child: MyApp(
          routeBundle: AppRouteBundle(
            authenticatedHome: '/home',
            loginBuilder: (context, state) => const Scaffold(
              body: Text('login page', key: ValueKey('route.login')),
            ),
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const Scaffold(
                  body: Text('home page', key: ValueKey('route.home')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // “没有登录会话”不等于“从未同意协议”。旧版本存在时状态机只会进入升级态，
    // 不会同时创建首次授权弹窗。
    expect(find.byKey(const ValueKey('route.login')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);

    // 即使自定义登录页在全局升级弹窗期间误调用登录前检查，也只阻断命令，不会
    // 再创建一层 showDialog。
    final blocked = await requestPrivacyConsentBeforeLogin(
      tester.element(find.byKey(const ValueKey('route.login'))),
      agreementSelected: false,
    );
    expect(blocked, isFalse);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
  });

  testWidgets('拒绝政策升级会清理会话并由路由守卫返回登录页', (tester) async {
    final sessionStore = _MemorySessionStore(
      const AuthSession(
        token: 'test-token',
        user: UserModel(id: '1', name: 'Tester', email: 't@example.test'),
      ),
    );
    final privacyRepository = _OldPrivacyRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyConfigProvider.overrideWithValue(_currentPolicy),
          privacyConsentRepositoryProvider.overrideWithValue(privacyRepository),
          sessionStoreProvider.overrideWithValue(sessionStore),
          // 本用例只验证隐私、认证和路由协作，不运行默认延迟初始化任务。
          appWarmupTasksProvider.overrideWithValue(const []),
        ],
        child: MyApp(
          routeBundle: AppRouteBundle(
            authenticatedHome: '/home',
            loginBuilder: (context, state) => const Scaffold(
              body: Text('login page', key: ValueKey('route.login')),
            ),
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const Scaffold(
                  body: Text('home page', key: ValueKey('route.home')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route.home')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);

    final declineButton = find.byKey(const ValueKey('privacy.decline'));
    await tester.ensureVisible(declineButton);
    await tester.tap(declineButton);
    await tester.pumpAndSettle();

    expect(sessionStore.clearCount, 1);
    expect(find.byKey(const ValueKey('route.login')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
    // 保留旧版本，才能让下次冷启动继续识别为“政策升级”而不是“首次安装”。
    expect(privacyRepository.acceptedVersion, '2025.01.01');
  });
}
