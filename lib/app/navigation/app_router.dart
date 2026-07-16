// lib/app/navigation/app_router.dart
//
// 作用：创建和配置 GoRouter 实例，管理所有页面路由声明和路由守卫。
//
// Tab 路由使用 StatefulShellRoute.indexedStack：
// - 三个 Tab 分支共享同一个 MainShell 实例，切换不会销毁子页面
// - GoRouter 的 StatefulNavigationShell 管理 Tab 状态，替代手写 IndexedStack + ViewModel

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth.dart';
import '../../features/home/home.dart';
import '../../features/learning/learning.dart';
import '../../features/mine/mine.dart';
import '../../features/orders/orders.dart';
import 'main_shell.dart';
import '../../shared/ui/loading_view.dart';
import 'not_found_page.dart';
import 'route_guard.dart';
import '../../shared/navigation/route_paths.dart';

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

      errorBuilder: (context, state) => const NotFoundPage(),

      redirect: (BuildContext context, GoRouterState state) {
        // 守卫按注册顺序执行，第一个返回路径的守卫终止后续判断。
        for (final guard in guards) {
          final redirectPath = guard.redirect(state);
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
        GoRoute(
          path: RoutePaths.riverpodLearning,
          // 学习中心在 Shell 外，返回时恢复“我的”页面的原分支状态。
          builder: (context, state) => const RiverpodLearningPage(),
        ),

        // 主框架：StatefulShellRoute 管理三个 Tab 分支
        // GoRouter 的 StatefulNavigationShell 保证子页面不会因为 Tab 切换而销毁
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            // Tab 0：商品目录与购物车
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.mainHome,
                  builder: (context, state) => const HomePage(),
                  routes: [
                    GoRoute(
                      // 子路由只写相对片段，完整地址为 /main/home/cart。
                      path: RoutePaths.cartSegment,
                      builder: (context, state) => const CartPage(),
                    ),
                  ],
                ),
              ],
            ),
            // Tab 1：订单列表与订单生命周期
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.mainOrders,
                  builder: (context, state) => const OrdersPage(),
                ),
              ],
            ),
            // Tab 2：我的与设置
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
        // 兼容业务代码或外部深链中的 /main，避免它落入 404 页面。
        GoRoute(
          path: RoutePaths.main,
          redirect: (context, state) => RoutePaths.mainHome,
        ),
      ],
    );
  }
}
