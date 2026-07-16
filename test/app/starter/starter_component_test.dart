// Starter 占位组件自己的测试。
//
// 真实项目删除 lib/app/starter 时，可以同时删除本测试目录；其余启动、路由和认证
// 测试使用自己的测试路由包，不依赖 Starter，仍能继续运行。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/app.dart';
import 'package:riverpod_mvvm/app/starter/starter.dart';
import 'package:riverpod_mvvm/app/starter/starter_home_page.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

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
  testWidgets('starter route completes authenticated home and logout loop', (
    tester,
  ) async {
    final store = _MemorySessionStore(
      const AuthSession(
        token: 'saved_token',
        user: UserModel(
          id: '1',
          name: 'Starter User',
          email: 'test@example.com',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
        child: MyApp(routeBundle: createStarterRouteBundle()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StarterHomePage), findsOneWidget);
    expect(find.text('Starter User'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(store.session, isNull);
    expect(find.byKey(const ValueKey('login.submit')), findsOneWidget);
  });
}
