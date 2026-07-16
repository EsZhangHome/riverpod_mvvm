// test/app/navigation/app_router_test.dart
// AppRouter 组装测试：只验证路由实例的所有权和稳定性，具体登录重定向规则
// 由 route_guard_test.dart 作为纯函数测试覆盖。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/navigation/app_router.dart';
import 'package:riverpod_mvvm/app/navigation/app_route_bundle.dart';
import 'package:riverpod_mvvm/app/navigation/route_guard.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

void main() {
  test('app router keeps the same GoRouter instance', () {
    // Arrange：refreshListenable 模拟 App 层的 Riverpod → GoRouter 桥接对象。
    final refreshListenable = ChangeNotifier();
    final appRouter = AppRouter(
      refreshListenable: refreshListenable,
      guards: [AuthRouteGuard(() => const AuthState.unauthenticated())],
      routeBundle: const AppRouteBundle.starter(),
    );
    addTearDown(appRouter.config.dispose);
    addTearDown(refreshListenable.dispose);

    // Act：多次读取 config 不应重新构造 GoRouter。
    final firstRouter = appRouter.config;
    final secondRouter = appRouter.config;

    // Assert：路由实例稳定，Widget 重建时不会丢失导航栈。
    expect(identical(firstRouter, secondRouter), isTrue);
  });
}
