// examples/demo_app/lib/demo_route_bundle.dart
//
// 教学应用的路由组合入口。它依赖底座公开的 AppRouteBundle，底座不反向依赖它。
// 删除整个 examples/demo_app 后，根项目的 AppRouter、登录和网络层都无需修改。

import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/riverpod_mvvm.dart';
import 'features/home/home.dart';
import 'features/learning/learning.dart';
import 'features/mine/mine.dart';
import 'features/orders/orders.dart';
import 'navigation/demo_route_paths.dart';
import 'navigation/main_shell.dart';

/// 创建完整教学案例路由。
///
/// 这是教学页面与通用底座之间唯一的组合点。
///
/// Demo 可以使用底座契约，底座源码却看不到任何 Demo 类型，依赖方向始终是
/// `demo_app -> riverpod_mvvm`。这比在根 pubspec 中声明可选 Demo 依赖更彻底。
AppRouteBundle createDemoRouteBundle() {
  return AppRouteBundle(
    authenticatedHome: DemoRoutePaths.mainHome,
    protectedPaths: const [DemoRoutePaths.riverpodLearning],
    protectedPrefixes: const [DemoRoutePaths.main],
    routes: [
      GoRoute(
        path: DemoRoutePaths.riverpodLearning,
        // 学习中心在 Tab Shell 外，返回后仍能恢复原来的 Tab 分支。
        builder: (context, state) => const RiverpodLearningPage(),
      ),
      // indexedStack 为每个 Tab 保留独立 Navigator 和页面树。
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: DemoRoutePaths.mainHome,
                builder: (context, state) => const HomePage(),
                routes: [
                  GoRoute(
                    // 子路由写相对片段，完整路径为 /main/home/cart。
                    path: DemoRoutePaths.cartSegment,
                    builder: (context, state) => const CartPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: DemoRoutePaths.mainOrders,
                builder: (context, state) => const OrdersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: DemoRoutePaths.mainMine,
                builder: (context, state) => const MinePage(),
              ),
            ],
          ),
        ],
      ),
      // 保留旧深链 /main，并明确送到第一个 Tab，而不是落到 404。
      GoRoute(
        path: DemoRoutePaths.main,
        redirect: (context, state) => DemoRoutePaths.mainHome,
      ),
    ],
  );
}
