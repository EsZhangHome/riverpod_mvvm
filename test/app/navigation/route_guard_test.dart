// 登录守卫规则测试。
//
// AuthRouteGuard 的核心规则保持为纯函数，因此不需要启动 MaterialApp、GoRouter 或
// ProviderScope，就能验证“会话恢复、公开/受保护深链、登录回跳和外部地址拦截”。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/navigation/route_guard.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';

const _businessHome = '/business/home';
const _businessRoot = '/business';
const _businessOrders = '/business/orders';
const _publicHelp = '/help';

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
    protectedPrefixes: const [_businessRoot],
  );

  String returnToOf(String location) {
    return Uri.parse(
      location,
    ).queryParameters[AuthRouteGuard.returnToQueryParameter]!;
  }

  group('AuthRouteGuard redirect matrix', () {
    test('normal launch stays on session restoring until auth is known', () {
      expect(
        guard.redirectLocation(RoutePaths.sessionRestoring, restoring),
        isNull,
      );
      expect(
        guard.redirectLocation(RoutePaths.sessionRestoring, loggedOut),
        RoutePaths.login,
      );
      expect(
        guard.redirectLocation(RoutePaths.sessionRestoring, loggedIn),
        _businessHome,
      );
    });

    test('restoring session preserves path, query, and fragment', () {
      const target = '/business/orders/100?tab=history#latest';
      final redirect = guard.redirectLocation(target, restoring)!;

      expect(Uri.parse(redirect).path, RoutePaths.sessionRestoring);
      expect(returnToOf(redirect), target);
    });

    test('logged-out protected deep link goes to login with returnTo', () {
      const target = '/business/orders/100?tab=history';
      final restoringLocation = guard.redirectLocation(target, restoring)!;
      final loginLocation = guard.redirectLocation(
        restoringLocation,
        loggedOut,
      )!;

      expect(Uri.parse(loginLocation).path, RoutePaths.login);
      expect(returnToOf(loginLocation), target);
      expect(guard.redirectLocation(loginLocation, loggedOut), isNull);
      expect(guard.redirectLocation(loginLocation, loggedIn), target);
    });

    test(
      'logged-out public deep link returns to public page after restore',
      () {
        const target = '$_publicHelp?article=start';
        final restoringLocation = guard.redirectLocation(target, restoring)!;

        expect(guard.redirectLocation(restoringLocation, loggedOut), target);
      },
    );

    test('authenticated home is protected even when not listed explicitly', () {
      final loginLocation = guard.redirectLocation(_businessHome, loggedOut)!;

      expect(Uri.parse(loginLocation).path, RoutePaths.login);
      expect(returnToOf(loginLocation), _businessHome);
    });

    test('protected prefix respects path segment boundary', () {
      expect(guard.redirectLocation(_businessOrders, loggedOut), isNotNull);
      expect(guard.redirectLocation('/business-v2', loggedOut), isNull);
    });

    test('external or internal flow returnTo is rejected', () {
      for (final unsafeTarget in [
        'https://evil.example/steal',
        '//evil.example/steal',
        RoutePaths.login,
        RoutePaths.sessionRestoring,
      ]) {
        final loginLocation = Uri(
          path: RoutePaths.login,
          queryParameters: {
            AuthRouteGuard.returnToQueryParameter: unsafeTarget,
          },
        ).toString();
        expect(
          guard.redirectLocation(loginLocation, loggedIn),
          _businessHome,
          reason: '$unsafeTarget must not be used as a redirect target',
        );
      }
    });
  });
}
