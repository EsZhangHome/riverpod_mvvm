// test/core/router/app_router_test.dart
//
// 迁移说明：AppRouter API 变更（AuthProvider → Listenable + guards）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/router/app_router.dart';
import 'package:riverpod_mvvm/core/router/route_guard.dart';

void main() {
  test('app router keeps the same GoRouter instance', () {
    final refreshListenable = ChangeNotifier();
    final appRouter = AppRouter(
      refreshListenable: refreshListenable,
      guards: [const AuthRouteGuard()],
    );

    final firstRouter = appRouter.config;
    final secondRouter = appRouter.config;

    expect(identical(firstRouter, secondRouter), isTrue);
  });
}
