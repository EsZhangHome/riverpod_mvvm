// 登录守卫规则测试。
//
// AuthRouteGuard 把状态读取和路径判断分开后，可以直接测试重定向矩阵，
// 不需要启动 MaterialApp、GoRouter 或 ProviderScope。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/navigation/route_guard.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';

// 这里故意使用测试自己的“业务路由”，而不是导入某个真实 feature。
//
// AuthRouteGuard 是企业底座能力，它只关心“哪些地址受保护”，不应该知道
// 首页、订单页等具体业务。测试遵守同一条依赖规则，替换业务模块后仍能原样运行。
const _businessHome = '/business/home';
const _businessRoot = '/business';
const _businessOrders = '/business/orders';
const _businessMine = '/business/mine';
const _businessLearning = '/business/learning';

void main() {
  const restoring = AuthState.restoring();
  const loggedOut = AuthState.unauthenticated();
  const loggedIn = AuthState.authenticated(
    AuthSession(
      token: 'token',
      user: UserModel(id: '1', name: 'Tester', email: 'test@example.com'),
    ),
  );
  final guard = AuthRouteGuard(
    () => loggedOut,
    authenticatedHome: _businessHome,
    protectedPaths: const [_businessLearning],
    protectedPrefixes: const [_businessRoot],
  );

  group('AuthRouteGuard redirect matrix', () {
    test('session restoration always stays on splash', () {
      expect(
        guard.redirectLocation(_businessHome, restoring),
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
        _businessHome,
      );
    });

    test('logged-out users cannot enter protected routes', () {
      for (final location in [
        _businessRoot,
        _businessHome,
        _businessOrders,
        _businessMine,
        _businessLearning,
      ]) {
        expect(
          guard.redirectLocation(location, loggedOut),
          RoutePaths.login,
          reason: '$location should require login',
        );
      }
    });

    test('logged-in users leave login and can enter protected routes', () {
      expect(guard.redirectLocation(RoutePaths.login, loggedIn), _businessHome);
      expect(guard.redirectLocation(_businessOrders, loggedIn), isNull);
    });
  });
}
