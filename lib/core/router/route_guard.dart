// lib/core/router/route_guard.dart
//
// 作用：定义路由守卫机制，控制用户在不同登录状态下能访问哪些页面。
//
// 迁移说明（Provider → Riverpod）：
// - AuthRouteGuard 不再持有 AuthProvider 引用
// - 改为通过 ProviderScope.containerOf(context).read(authProvider) 获取登录状态
// - RouteGuard 接口不变
//
// 扩展方式：
// ```dart
// class VipRouteGuard implements RouteGuard {
//   @override
//   String? redirect(GoRouterState state, BuildContext context) {
//     final authState = ProviderScope.containerOf(context).read(authProvider);
//     if (state.matchedLocation == '/vip' && !user.isVip) {
//       return '/upgrade';
//     }
//     return null;
//   }
// }
// ```

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../global/auth_provider.dart';
import 'route_paths.dart';

/// 路由守卫抽象接口。
///
/// 每个守卫实现一个特定的拦截规则。
/// 所有守卫在 AppRouter 的 redirect 中按顺序执行，
/// 第一个返回非 null 路径的守卫决定最终的重定向目标。
abstract class RouteGuard {
  /// 检查当前路由是否需要重定向。
  ///
  /// [state]：GoRouter 当前状态，包含 matchedLocation
  /// [context]：当前 BuildContext，可通过 ProviderScope.containerOf 获取 Riverpod 状态
  String? redirect(GoRouterState state, BuildContext context);
}

/// 登录状态路由守卫。
///
/// 通过 Riverpod 的 ProviderScope.containerOf 获取登录状态，不持有引用。
///
/// 拦截规则：
/// 1. 恢复登录态期间 → 停留在启动页
/// 2. 恢复完成后 → 根据登录状态跳转到主页或登录页
/// 3. 未登录 + 受保护页面 → 重定向到登录页
/// 4. 已登录 + 登录页 → 重定向到主页面
class AuthRouteGuard implements RouteGuard {
  const AuthRouteGuard();

  /// 受保护页面（需要登录才能访问）
  /// /main 是 StatefulShellRoute 外壳，/main/home 为实际首页 Tab
  static const _protectedRoutes = {
    RoutePaths.main,
    RoutePaths.mainHome,
    RoutePaths.mainCommunity,
    RoutePaths.mainMine,
  };

  @override
  String? redirect(GoRouterState state, BuildContext context) {
    // 通过 ProviderScope 获取当前登录状态
    final container = ProviderScope.containerOf(context);
    final authState = container.read(authProvider);

    final isLoginRoute = state.matchedLocation == RoutePaths.login;
    final isSplashRoute = state.matchedLocation == RoutePaths.splash;
    final isProtectedRoute = _protectedRoutes.contains(state.matchedLocation);

    // 规则 0：恢复登录态期间停留在启动页
    if (authState.isRestoringSession) {
      return isSplashRoute ? null : RoutePaths.splash;
    }

    // 规则 0.1：恢复完成后离开启动页
    if (isSplashRoute) {
      return authState.isLoggedIn ? RoutePaths.mainHome : RoutePaths.login;
    }

    // 规则 1：未登录 → 不能访问受保护页面
    if (!authState.isLoggedIn && isProtectedRoute) {
      return RoutePaths.login;
    }

    // 规则 2：已登录 → 不需要停留在登录页
    if (authState.isLoggedIn && isLoginRoute) {
      return RoutePaths.mainHome;
    }

    // 规则 3：其他情况放行
    return null;
  }
}
