// test/widget_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/app/app.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/shared/localization/app_strings.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';

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

    // Act：挂载完整 App，ProviderScope、AuthNotifier、GoRouter 都走生产组装路径。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsWidgets);
    expect(find.text('Riverpod MVVM'), findsOneWidget);

    // Starter 是底座默认的受保护占位页，未登录时必须被守卫拦截。
    tester.element(find.text(AppStrings.login).first).go(RoutePaths.starter);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.login), findsWidgets);
    expect(find.text(AppStrings.pageNotFound), findsNothing);

    // 默认 MyApp 只注册底座页面，具体业务路由必须由项目入口显式注入。
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('登录'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
  });
}

// App 根级 Widget 测试：关注启动期会话恢复和路由守卫，不测试具体业务列表。
