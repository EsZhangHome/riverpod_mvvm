// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/app/app.dart';
import 'package:riverpod_mvvm/app/navigation/app_route_bundle.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/l10n/app_localizations.dart';
import 'package:riverpod_mvvm/shared/ui/error_view.dart';

const _testHomePath = '/test-home';

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

void main() {
  testWidgets('app starts at login page when there is no token', (
    tester,
  ) async {
    // Arrange：注入空会话，测试不依赖设备 Keychain/Keystore 插件。
    final store = _MemorySessionStore(null);
    final routeBundle = _createTestRouteBundle();

    // Act：挂载完整 App，ProviderScope、AuthNotifier、GoRouter 都走生产组装路径。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
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

  testWidgets('empty login form shows toast and keeps the form visible', (
    tester,
  ) async {
    final store = _MemorySessionStore(null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
        child: MyApp(routeBundle: _createTestRouteBundle()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('login.submit')));
    // 第一次 pump 处理 Provider 更新，第二次推进 Overlay Toast 的进入动画。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final loginContext = tester.element(
      find.byKey(const ValueKey('login.submit')),
    );
    expect(
      find.text(AppLocalizations.of(loginContext).enterAccount),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(ErrorView), findsNothing);
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
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
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
