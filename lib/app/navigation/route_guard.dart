// lib/app/navigation/route_guard.dart
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

import '../../features/auth/auth.dart';
import '../../shared/navigation/route_paths.dart';

/// 路由守卫抽象接口。
///
/// 每个守卫实现一个特定的拦截规则。
/// 所有守卫在 AppRouter 的 redirect 中按顺序执行，
/// 第一个返回非 null 路径的守卫决定最终的重定向目标。
abstract class RouteGuard {
  /// 检查当前路由是否需要重定向。
  ///
  /// [state] 是 GoRouter 当前导航快照：`uri` 保留 path/query/fragment，
  /// `matchedLocation` 只表示已经匹配到的路由层级。认证守卫使用完整 uri 保存深链；
  /// 其他权限守卫可按自己的规则选择字段。
  ///
  /// 返回值含义：
  /// - 返回 null：当前守卫放行，GoRouter 继续询问后续守卫；
  /// - 返回路径：立即重定向到该地址，后续守卫本轮不再执行。
  String? redirect(GoRouterState state);
}

/// 登录状态路由守卫。
///
/// 通过构造参数读取最新登录状态，不依赖 ProviderScope 或具体状态管理框架。
///
/// 拦截规则：
/// 1. 恢复登录态期间 → 停留在会话恢复页并保存安全 returnTo；
/// 2. 恢复完成后 → 优先返回原目标，没有目标时进入首页或登录页；
/// 3. 未登录 + 受保护页面 → 携带 returnTo 重定向到登录页；
/// 4. 已登录 + 登录页 → 返回原目标或项目首页。
class AuthRouteGuard implements RouteGuard {
  /// 登录页和会话恢复页保存原目标地址时使用的 query 参数名。
  ///
  /// 例如 `/login?returnTo=%2Forders%2F100`。值在使用前必须通过
  /// [_parseSafeReturnTo] 校验，不能把外部 URL 当作跳转目标。
  static const returnToQueryParameter = 'returnTo';

  /// 创建登录态守卫。
  ///
  /// - [_readAuthState]：每次 redirect 时读取最新 AuthState 的函数。使用回调而不是
  ///   保存某次 AuthState，避免守卫长期持有过期登录快照。
  /// - [authenticatedHome]：没有 returnTo 时，已登录用户的默认目标地址；它会自动
  ///   作为受保护页面；
  /// - [loginPath]：未登录用户访问受保护页面时的目标地址。
  /// - [protectedPaths]：只保护完全相等地址的精确名单。
  /// - [protectedPrefixes]：保护某个地址及其全部 `/` 子路径的前缀名单。
  ///
  /// 后四项通常全部来自同一个 AppRouteBundle，确保“路由注册”和“守卫规则”使用
  /// 同一份配置，不要在 AppRouter 中再手写第二套业务路径。
  const AuthRouteGuard(
    this._readAuthState, {
    required this.authenticatedHome,
    this.loginPath = RoutePaths.login,
    this.protectedPaths = const [],
    this.protectedPrefixes = const [],
  });

  /// App 层通常传入 `() => ref.read(authProvider)`。
  /// 测试则传入普通闭包，因此不需要挂载 ProviderScope。
  final AuthState Function() _readAuthState;

  /// 当前项目声明的登录后首页。不同项目可以不同，守卫不写死业务路径。
  /// 该值必须能被 GoRouter 匹配，否则重定向后会进入 404。
  final String authenticatedHome;

  /// 当前项目的未认证入口，不假设一定是账号密码页面。
  /// AppRouteBundle.loginBuilder 决定这个地址实际构建哪个登录 Widget。
  final String loginPath;

  /// 业务模块声明的精确受保护地址；不自动包含子路径。
  final List<String> protectedPaths;

  /// 业务模块声明的受保护前缀；匹配前缀本身及其 `/` 子路径。
  /// 例如 `/orders` 会匹配 `/orders/1`，但不会匹配 `/orders-v2`。
  final List<String> protectedPrefixes;

  @override
  String? redirect(GoRouterState state) {
    // 每次 GoRouter 执行 redirect 时读取最新快照，不缓存过期登录状态。
    final authState = _readAuthState();
    // state.uri 同时保留 path 和 query。只使用 matchedLocation 会丢失订单 id、筛选项
    // 等深链参数，也无法在登录后准确返回用户原来想访问的页面。
    return redirectUri(state.uri, authState);
  }

  /// 纯函数形式的守卫规则。
  ///
  /// [location] 是待访问的内部 URI 字符串，可以包含 query/fragment；[authState]
  /// 是这一时刻的认证快照。
  /// 返回 null 表示放行，返回路径表示重定向。把核心规则拆成纯函数后，测试可以
  /// 覆盖“恢复中/未登录/已登录 × 登录页/恢复页/受保护页/公开页”的完整矩阵，
  /// 而不需要构造复杂的 GoRouterState。
  String? redirectLocation(String location, AuthState authState) {
    return redirectUri(Uri.parse(location), authState);
  }

  /// 使用完整 URI 执行认证重定向规则。
  ///
  /// 该方法同时处理四个企业级场景：
  /// 1. 冷启动期间只显示会话恢复页，不闪现登录页；
  /// 2. 任何项目的 [authenticatedHome] 都自动受保护，避免入口配置遗漏；
  /// 3. 通知/深链原始 path、query、fragment 会通过安全 returnTo 保留；
  /// 4. 未登录访问公开页面时，恢复结束后仍回公开页面，不强制进入登录页。
  ///
  /// [location] 必须是 GoRouter 当前内部 URI；[authState] 是这一时刻的认证快照。
  /// 返回 null 表示放行，返回字符串表示 GoRouter 应重定向到该内部地址。
  String? redirectUri(Uri location, AuthState authState) {
    final path = location.path;
    final isLoginRoute = path == loginPath;
    final isRestoringRoute = path == RoutePaths.sessionRestoring;

    // 规则 1：安全会话尚未读取完成。
    // - 已在恢复页时放行，避免 redirect 循环；
    // - 其他内部地址作为 returnTo 暂存。若当前就是登录页，则只保留登录页已有的
    //   安全 returnTo，不把 /login 本身当成恢复后的业务目标。
    if (authState.isRestoringSession) {
      if (isRestoringRoute) return null;
      final target = isLoginRoute
          ? _returnToFrom(location)
          : _safeCurrentLocation(location);
      return _routeWithReturnTo(RoutePaths.sessionRestoring, target);
    }

    // 规则 2：恢复完成，离开内部恢复页。
    // 有 returnTo 时优先恢复原目标；没有时才根据登录状态选择首页或登录页。
    if (isRestoringRoute) {
      final target = _returnToFrom(location);
      if (target == null) {
        return authState.isLoggedIn ? authenticatedHome : loginPath;
      }
      if (!authState.isLoggedIn && _isProtectedPath(target.path)) {
        return _routeWithReturnTo(loginPath, target);
      }
      return target.toString();
    }

    // 规则 3：已登录用户无需停留在登录页。
    // 登录页可能携带受保护深链；成功后优先返回它，否则进入项目首页。
    if (isLoginRoute && authState.isLoggedIn) {
      return _returnToFrom(location)?.toString() ?? authenticatedHome;
    }

    // 规则 4：未登录访问受保护页面。
    // authenticatedHome 永远自动受保护，项目不需要在 protectedPaths 重复声明。
    if (!authState.isLoggedIn && _isProtectedPath(path)) {
      return _routeWithReturnTo(loginPath, _safeCurrentLocation(location));
    }

    // 登录页（未登录）和其他公开页面直接放行。
    return null;
  }

  /// 判断 [path] 是否必须登录。
  ///
  /// 首页使用安全默认值自动保护；精确路径与前缀继续来自 AppRouteBundle。前缀只匹配
  /// 自身或紧随 `/` 的子路径，`/orders` 不会误伤 `/orders-v2`。
  bool _isProtectedPath(String path) {
    return path == authenticatedHome ||
        protectedPaths.contains(path) ||
        protectedPrefixes.any(
          (prefix) => path == prefix || path.startsWith('$prefix/'),
        );
  }

  /// 从登录页或会话恢复页读取并校验 returnTo。
  Uri? _returnToFrom(Uri route) {
    return _parseSafeReturnTo(route.queryParameters[returnToQueryParameter]);
  }

  /// 校验 GoRouter 当前地址可否作为内部回跳目标。
  Uri? _safeCurrentLocation(Uri location) {
    return _parseSafeReturnTo(location.toString());
  }

  /// 只接受 App 内部绝对路径，拒绝外部 URL 和内部流程页。
  ///
  /// 安全条件：
  /// - 不能带 scheme/authority，例如 `https://evil.example` 或 `//evil.example`；
  /// - path 必须以 `/` 开头；
  /// - 不能指回登录页或会话恢复页，否则登录状态变化会形成循环。
  ///
  /// 未注册但格式安全的内部路径可以保留，之后由 GoRouter 统一显示 404；守卫不应
  /// 复制整套路由表来判断页面是否存在。
  Uri? _parseSafeReturnTo(String? rawTarget) {
    if (rawTarget == null || rawTarget.isEmpty) return null;
    final target = Uri.tryParse(rawTarget);
    if (target == null ||
        target.hasScheme ||
        target.hasAuthority ||
        !target.path.startsWith('/') ||
        target.path == loginPath ||
        target.path == RoutePaths.sessionRestoring) {
      return null;
    }
    return target;
  }

  /// 生成内部流程页地址，并由 [Uri] 负责安全编码 returnTo query 值。
  String _routeWithReturnTo(String path, Uri? target) {
    if (target == null) return path;
    return Uri(
      path: path,
      queryParameters: {returnToQueryParameter: target.toString()},
    ).toString();
  }
}
