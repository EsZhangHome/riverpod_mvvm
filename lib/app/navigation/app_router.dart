// lib/app/navigation/app_router.dart
//
// AppRouter 只负责“稳定底座路由 + 路由守卫 + 外部业务路由”的组装。
// 它刻意不 import 任何具体业务 feature，保证底座路由器可以跨项目复用。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth.dart';
import '../../shared/navigation/route_paths.dart';
import '../../shared/ui/loading_view.dart';
import 'app_route_bundle.dart';
import 'not_found_page.dart';
import 'route_guard.dart';

/// 持有当前 App Widget 生命周期内稳定的 GoRouter。
///
/// [routeBundle] 由项目入口提供。
/// 这种构造注入让路由器依赖抽象配置，而不是依赖某个项目的具体页面。
class AppRouter {
  /// 创建并持有一份 GoRouter 配置。
  ///
  /// - [refreshListenable]：认证状态变化时发出通知，使 GoRouter 重新执行 redirect。
  ///   它只负责“通知有变化”，真实状态仍由 Guard 的读取函数取得。
  /// - [guards]：按列表顺序执行的路由守卫。第一个返回非 null 地址的守卫获胜；
  ///   顺序通常应从登录态、租户选择等基础守卫排到更具体的权限守卫。
  /// - [routeBundle]：项目入口提供的业务路由、首页、登录页和保护规则。
  ///
  /// AppRouter 构造时就创建 [config]。调用方应在 StatefulWidget 生命周期内只构造
  /// 一次，并在 dispose 时释放 [config]，不能在每次 build 中重新创建。
  AppRouter({
    required Listenable refreshListenable,
    required List<RouteGuard> guards,
    required AppRouteBundle routeBundle,
  }) : config = _createRouter(refreshListenable, guards, routeBundle);

  /// 已完成底座路由和业务路由组装的 GoRouter 实例。
  ///
  /// `MaterialApp.router(routerConfig: ...)` 直接使用它。GoRouter 内部保存导航栈、
  /// 当前地址和 Listenable 订阅，因此必须长期持有，不能在 Widget 每次 build 时
  /// 重新创建。
  final GoRouter config;

  static GoRouter _createRouter(
    Listenable refreshListenable,
    List<RouteGuard> guards,
    AppRouteBundle routeBundle,
  ) {
    return GoRouter(
      // 普通冷启动明确从“恢复安全会话”开始，而不是先假装进入登录后首页再重定向。
      // GoRouter 默认仍优先使用平台提供的深链地址；守卫会把原地址编码进 returnTo，
      // 恢复/登录完成后再返回目标页面，不会把通知或外部链接丢成首页。
      initialLocation: RoutePaths.sessionRestoring,
      overridePlatformDefaultLocation: false,
      refreshListenable: refreshListenable,
      // 所有 routes 都无法匹配时进入 404。fallbackPath 选择登录入口，是因为
      // 已登录用户进入登录页后还会被 Guard 送回 authenticatedHome。
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
        // 通用路由器只注册所有项目都需要的登录入口与会话恢复页。
        // Starter 或真实业务首页必须由 routeBundle.routes 提供。
        GoRoute(
          path: routeBundle.loginPath,
          builder:
              routeBundle.loginBuilder ?? (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: RoutePaths.sessionRestoring,
          builder: (context, state) => const Scaffold(body: LoadingView()),
        ),

        // 展开入口提供的路由组件。默认 Starter 和真实项目使用完全相同的组合方式。
        ...routeBundle.routes,
      ],
    );
  }
}
