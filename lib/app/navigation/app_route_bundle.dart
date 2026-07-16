// lib/app/navigation/app_route_bundle.dart
//
// 这个文件定义“业务路由包”的最小契约。
//
// 为什么不把所有业务页面直接写进 AppRouter？
// 通用路由器一旦 import 具体项目页面，就无法在新项目中稳定复用。把业务路由
// 作为参数传入后：
// - AppRouter 只认识登录、启动页、404 等底座页面；
// - main.dart 默认进入待替换的 StarterPage；
// - 真实项目在自己的组合文件中注入首页、路由和受保护路径。

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../shared/navigation/route_paths.dart';

/// 一组可以插入 AppRouter 的业务路由及其导航规则。
///
/// 它只保存“组合信息”，不保存登录状态，也不处理业务逻辑。
/// 登录状态仍由 AuthNotifier 管理，重定向仍由 AuthRouteGuard 管理。
class AppRouteBundle {
  const AppRouteBundle({
    required this.authenticatedHome,
    this.loginPath = RoutePaths.login,
    this.loginBuilder,
    this.routes = const [],
    this.protectedPaths = const [],
    this.protectedPrefixes = const [],
  });

  /// 底座默认路由包：登录后进入等待真实业务替换的 StarterPage。
  /// 名字表示“起步占位”，与 development/production 环境无关。
  const AppRouteBundle.starter()
    : authenticatedHome = RoutePaths.starter,
      loginPath = RoutePaths.login,
      loginBuilder = null,
      routes = const [],
      protectedPaths = const [],
      protectedPrefixes = const [];

  /// 登录成功或会话恢复完成后应该进入的地址。
  final String authenticatedHome;

  /// 未认证用户进入的地址，可由 SSO、验证码等项目替换。
  final String loginPath;

  /// 自定义登录页面。为空时使用底座账号密码 LoginPage。
  final Widget Function(BuildContext context, GoRouterState state)?
  loginBuilder;

  /// 由具体项目提供的业务路由。底座路由不放在这里，避免被业务覆盖。
  final List<RouteBase> routes;

  /// 需要登录的精确路径，例如 `/reports`。
  final List<String> protectedPaths;

  /// 需要登录的路径前缀，例如 `/workspace` 会保护它及其所有子路径。
  final List<String> protectedPrefixes;
}
