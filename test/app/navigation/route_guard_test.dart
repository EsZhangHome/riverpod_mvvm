// 登录守卫规则测试。
//
// AuthRouteGuard 把状态读取和路径判断分开后，可以直接测试重定向矩阵，
// 不需要启动 MaterialApp、GoRouter 或 ProviderScope。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/navigation/route_guard.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

void main() {
  const restoring = AuthState(isRestoringSession: true);
  const loggedOut = AuthState();
  const loggedIn = AuthState(token: 'token');
  final guard = AuthRouteGuard(() => loggedOut);

  group('AuthRouteGuard redirect matrix', () {
    test('session restoration always stays on splash', () {
      expect(
        guard.redirectLocation(RoutePaths.mainHome, restoring),
        RoutePaths.splash,
      );
      expect(guard.redirectLocation(RoutePaths.splash, restoring), isNull);
    });

    test('leaving splash follows the restored login state', () {
      expect(
        guard.redirectLocation(RoutePaths.splash, loggedOut),
        RoutePaths.login,
      );
      expect(
        guard.redirectLocation(RoutePaths.splash, loggedIn),
        RoutePaths.mainHome,
      );
    });

    test('logged-out users cannot enter protected routes', () {
      for (final location in [
        RoutePaths.main,
        RoutePaths.mainHome,
        RoutePaths.mainOrders,
        RoutePaths.mainMine,
        RoutePaths.riverpodLearning,
      ]) {
        expect(
          guard.redirectLocation(location, loggedOut),
          RoutePaths.login,
          reason: '$location should require login',
        );
      }
    });

    test('logged-in users leave login and can enter protected routes', () {
      expect(
        guard.redirectLocation(RoutePaths.login, loggedIn),
        RoutePaths.mainHome,
      );
      expect(guard.redirectLocation(RoutePaths.mainOrders, loggedIn), isNull);
    });
  });
}
