// lib/core/router/route_guard.dart
//
// 作用：定义路由守卫机制，控制用户在不同登录状态下能访问哪些页面。
//
// 扩展方式：
// ```dart
// class VipRouteGuard implements RouteGuard {
//   VipRouteGuard(this.readUser);
//   final User Function() readUser;
//
//   @override
//   String? redirect(GoRouterState state) {
//     if (state.matchedLocation == '/vip' && !readUser().isVip) {
//       return '/upgrade';
//     }
//     return null;
//   }
// }
// ```

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
  String? redirect(GoRouterState state);
}

/// 登录状态路由守卫。
///
/// 通过构造参数读取最新登录状态，不依赖 ProviderScope 或具体状态管理框架。
///
/// 拦截规则：
/// 1. 恢复登录态期间 → 停留在启动页
/// 2. 恢复完成后 → 根据登录状态跳转到主页或登录页
/// 3. 未登录 + 受保护页面 → 重定向到登录页
/// 4. 已登录 + 登录页 → 重定向到主页面
class AuthRouteGuard implements RouteGuard {
  const AuthRouteGuard(this._readAuthState);

  /// App 层通常传入 `() => ref.read(authProvider)`。
  /// 测试则传入普通闭包，因此不需要挂载 ProviderScope。
  final AuthState Function() _readAuthState;

  @override
  String? redirect(GoRouterState state) {
    // 每次 GoRouter 执行 redirect 时读取最新快照，不缓存过期登录状态。
    final authState = _readAuthState();
    return redirectLocation(state.matchedLocation, authState);
  }

  /// 纯函数形式的守卫规则，方便覆盖完整重定向矩阵而无需构造 GoRouterState。
  String? redirectLocation(String location, AuthState authState) {
    final isLoginRoute = location == RoutePaths.login;
    final isSplashRoute = location == RoutePaths.splash;
    // 统一保护 /main 后代路由以及从“我的”进入的学习中心。
    final isProtectedRoute =
        location == RoutePaths.main ||
        location.startsWith('${RoutePaths.main}/') ||
        location == RoutePaths.riverpodLearning;

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
