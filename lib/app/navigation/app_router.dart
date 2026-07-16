// lib/app/navigation/app_router.dart
//
// AppRouter 只负责“稳定底座路由 + 路由守卫 + 外部业务路由”的组装。
// 它刻意不 import 任何具体业务 feature，保证底座路由器可以跨项目复用。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth.dart';
import '../../shared/navigation/route_paths.dart';
import '../../shared/ui/loading_view.dart';
import '../starter/starter_page.dart';
import 'app_route_bundle.dart';
import 'not_found_page.dart';
import 'route_guard.dart';

/// 持有当前 App Widget 生命周期内稳定的 GoRouter。
///
/// [routeBundle] 由项目入口提供。
/// 这种构造注入让路由器依赖抽象配置，而不是依赖某个项目的具体页面。
class AppRouter {
  AppRouter({
    required Listenable refreshListenable,
    required List<RouteGuard> guards,
    required AppRouteBundle routeBundle,
  }) : config = _createRouter(refreshListenable, guards, routeBundle);

  /// GoRouter 必须长期持有，不能在 Widget 每次 build 时重新创建。
  final GoRouter config;

  static GoRouter _createRouter(
    Listenable refreshListenable,
    List<RouteGuard> guards,
    AppRouteBundle routeBundle,
  ) {
    return GoRouter(
      // 初始地址可以是受保护页面。未登录时 AuthRouteGuard 会立即转到登录页；
      // 已恢复会话时则直接进入业务首页，避免先显示登录页再闪烁跳转。
      initialLocation: routeBundle.authenticatedHome,
      refreshListenable: refreshListenable,
      errorBuilder: (context, state) =>
          NotFoundPage(fallbackPath: routeBundle.loginPath),
      redirect: (BuildContext context, GoRouterState state) {
        // 多个守卫按顺序组成责任链，第一个给出重定向地址的守卫生效。
        for (final guard in guards) {
          final redirectPath = guard.redirect(state);
          if (redirectPath != null) return redirectPath;
        }
        return null;
      },
      routes: [
        // 以下是底座内置路由。真实项目通常替换登录页和 authenticatedHome；
        // 未被导航到的 StarterPage 不会进入业务页面栈。
        GoRoute(
          path: routeBundle.loginPath,
          builder:
              routeBundle.loginBuilder ?? (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: RoutePaths.splash,
          builder: (context, state) => const Scaffold(body: LoadingView()),
        ),
        GoRoute(
          path: RoutePaths.starter,
          builder: (context, state) => const StarterPage(),
        ),

        // 展开业务路由。底座默认是空列表；真实项目在入口层提供。
        ...routeBundle.routes,
      ],
    );
  }
}
