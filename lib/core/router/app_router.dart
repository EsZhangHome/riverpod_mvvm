// lib/core/router/app_router.dart
//
// 作用：创建和配置 GoRouter 实例，管理所有页面路由声明和路由守卫。
//
// Tab 路由使用 StatefulShellRoute.indexedStack：
// - 三个 Tab 分支共享同一个 MainPage 实例，切换不会销毁子页面
// - GoRouter 的 StatefulNavigationShell 管理 Tab 状态，替代手写 IndexedStack + ViewModel

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/community/view/community_page.dart';
import '../../features/home/view/home_page.dart';
import '../../features/login/view/login_page.dart';
import '../../features/main/view/main_page.dart';
import '../../features/mine/view/mine_page.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/not_found_view.dart';
import 'route_guard.dart';
import 'route_paths.dart';

/// App 路由管理器。
class AppRouter {
  AppRouter({
    required Listenable refreshListenable,
    required List<RouteGuard> guards,
  }) : config = _createRouter(refreshListenable, guards);

  final GoRouter config;

  static GoRouter _createRouter(
    Listenable refreshListenable,
    List<RouteGuard> guards,
  ) {
    return GoRouter(
      // StatefulShellRoute 默认进入第一个分支（首页 Tab）
      initialLocation: RoutePaths.mainHome,
      refreshListenable: refreshListenable,

      errorBuilder: (context, state) => const NotFoundView(),

      redirect: (BuildContext context, GoRouterState state) {
        for (final guard in guards) {
          final redirectPath = guard.redirect(state, context);
          if (redirectPath != null) return redirectPath;
        }
        return null;
      },

      routes: [
        GoRoute(
          path: RoutePaths.login,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: RoutePaths.splash,
          builder: (context, state) => const Scaffold(body: LoadingView()),
        ),

        // 主框架：StatefulShellRoute 管理三个 Tab 分支
        // GoRouter 的 StatefulNavigationShell 保证子页面不会因为 Tab 切换而销毁
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainPage(navigationShell: navigationShell),
          branches: [
            // Tab 0：首页
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.mainHome,
                  builder: (context, state) => const HomePage(),
                ),
              ],
            ),
            // Tab 1：社区
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.mainCommunity,
                  builder: (context, state) => const CommunityPage(),
                ),
              ],
            ),
            // Tab 2：我的
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.mainMine,
                  builder: (context, state) => const MinePage(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
