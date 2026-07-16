// lib/app/navigation/app_route_bundle.dart
//
// 这个文件定义“业务路由包”的最小契约。
//
// 为什么不把所有业务页面直接写进 AppRouter？
// 通用路由器一旦 import 具体项目页面，就无法在新项目中稳定复用。把业务路由
// 作为参数传入后：
// - AppRouter 只认识登录、会话恢复、404 等底座页面；
// - 真实项目在自己的组合文件中注入首页、路由和受保护路径。

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../shared/navigation/route_paths.dart';

/// 一组可以插入 AppRouter 的业务路由及其导航规则。
///
/// 它只保存“组合信息”，不保存登录状态，也不处理业务逻辑。
/// 登录状态仍由 AuthNotifier 管理，重定向仍由 AuthRouteGuard 管理。
///
/// 最小接入示例：
/// ```dart
/// AppRouteBundle createProjectRouteBundle() {
///   return AppRouteBundle(
///     // 必须和 routes 中某个 GoRoute 的完整 path 一致。
///     authenticatedHome: '/workspace/home',
///     // 保护 /workspace 本身及 /workspace/... 的所有子路径。
///     protectedPrefixes: const ['/workspace'],
///     routes: [
///       GoRoute(
///         path: '/workspace/home',
///         builder: (context, state) => const WorkspacePage(),
///       ),
///     ],
///   );
/// }
/// ```
class AppRouteBundle {
  /// 创建一个项目自己的路由组合。
  ///
  /// 参数可以分成三组理解：
  /// 1. [authenticatedHome] 决定“登录成功后去哪里”；
  /// 2. [loginPath]、[loginBuilder] 决定“未登录时看到什么”；
  /// 3. [routes]、[protectedPaths]、[protectedPrefixes] 描述项目有哪些业务页面，
  ///    以及其中哪些页面必须登录。
  ///
  /// 本对象不会自动创建业务路由。[authenticatedHome] 指向的地址必须已经存在于
  /// [routes]。如果只填写首页字符串却没有注册对应 `GoRoute`，GoRouter 会进入
  /// 404 页面。
  ///
  /// 登录后首页会被 `AuthRouteGuard` 自动视为受保护路由，不需要再重复写入
  /// [protectedPaths]。其他受保护详情页或整个业务路由树仍需在下面两个列表声明。
  AppRouteBundle({
    required String authenticatedHome,
    String loginPath = RoutePaths.login,
    this.loginBuilder,
    List<RouteBase> routes = const [],
    List<String> protectedPaths = const [],
    List<String> protectedPrefixes = const [],
  }) : authenticatedHome = _validatePath(
         parameterName: 'authenticatedHome',
         value: authenticatedHome,
       ),
       loginPath = _validatePath(parameterName: 'loginPath', value: loginPath),
       routes = List<RouteBase>.unmodifiable(routes),
       protectedPaths = List<String>.unmodifiable(
         protectedPaths.map(
           (path) =>
               _validatePath(parameterName: 'protectedPaths', value: path),
         ),
       ),
       protectedPrefixes = List<String>.unmodifiable(
         protectedPrefixes.map(
           (path) =>
               _validatePath(parameterName: 'protectedPrefixes', value: path),
         ),
       ) {
    if (this.authenticatedHome == this.loginPath) {
      throw ArgumentError.value(
        authenticatedHome,
        'authenticatedHome',
        '不能与 loginPath 相同',
      );
    }
    if (this.authenticatedHome == RoutePaths.sessionRestoring ||
        this.loginPath == RoutePaths.sessionRestoring) {
      throw ArgumentError(
        'authenticatedHome 和 loginPath 不能使用底座内部会话恢复地址 '
        '${RoutePaths.sessionRestoring}',
      );
    }
  }

  /// 校验入口声明的是 App 内部“纯路径”。
  ///
  /// [parameterName] 只用于生成容易定位的异常信息；[value] 是调用方传入的路径。
  /// 路由保护比较只看 URI path，因此这里禁止 scheme、authority、query 和 fragment，
  /// 防止有人把完整 URL 或 `/home?tab=1` 错当成路由注册路径。动态参数应交给具体
  /// GoRoute 和导航调用，不能写进路由包的保护规则。
  static String _validatePath({
    required String parameterName,
    required String value,
  }) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        value.isEmpty ||
        !value.startsWith('/') ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        value,
        parameterName,
        '必须是以 / 开头且不含域名、query、fragment 的 App 内部路径',
      );
    }
    return value;
  }

  /// 登录成功或已登录会话恢复完成后进入的首页地址。
  ///
  /// 它是一个“路由路径”，不是 Widget，也不是路由名称。例如
  /// `/workspace/home`。通常必须满足：
  /// - 以 `/` 开头，表示绝对路径；
  /// - 在 [routes] 中存在可匹配的 `GoRoute`；
  /// - 不能与 [loginPath] 或 `/session-restoring` 相同。
  ///
  /// 普通冷启动先进入 `/session-restoring`。会话恢复完成、登录成功或已登录用户
  /// 误入登录页时，本字段才作为默认目标；存在安全 returnTo 时会优先返回原目标。
  /// 它不会决定当前构建是不是生产环境。
  final String authenticatedHome;

  /// 未认证用户应该进入的登录地址，默认是底座的 `/login`。
  ///
  /// 大多数账号密码项目无需修改。SSO、短信验证码或品牌独立登录页可以改成
  /// `/sso-login` 等地址，并配合 [loginBuilder] 返回对应页面。
  /// AppRouter 会自动为该路径创建登录路由，因此不要再在 [routes] 中注册同一路径，
  /// 否则会出现重复路由。
  final String loginPath;

  /// 自定义登录页面构建函数；为空时使用底座账号密码 LoginPage。
  ///
  /// 回调的两个参数由 GoRouter 提供：
  /// - `context`：当前页面的 BuildContext，用于读取主题、本地化等 Widget 能力；
  /// - `state`：当前 GoRouterState，可读取 path/query 参数或外部跳转携带的数据。
  ///
  /// 示例：
  /// ```dart
  /// loginPath: '/sso-login',
  /// loginBuilder: (context, state) => const SsoLoginPage(),
  /// ```
  ///
  /// 这里只负责“创建登录页面”。登录成功后仍应更新 authProvider，由路由守卫
  /// 根据最新 AuthState 自动跳转，而不是在登录页面写死业务首页路径。
  final Widget Function(BuildContext context, GoRouterState state)?
  loginBuilder;

  /// 具体项目拥有的业务路由集合，默认没有任何业务路由。
  ///
  /// 元素类型是 `RouteBase`，所以不只支持普通 `GoRoute`，还可以放入
  /// `ShellRoute`、`StatefulShellRoute` 等 GoRouter 路由结构。列表会被展开到
  /// 底座路由之后。
  ///
  /// 不要在这里重复注册底座已经管理的 [loginPath] 或 `/session-restoring`。
  /// 业务页面、Tab 外壳和详情子路由应由项目在这里集中组合。
  /// 构造时会复制成不可变列表，避免 GoRouter 创建后被外部代码原地修改。
  final List<RouteBase> routes;

  /// 需要登录的“精确路径”列表。
  ///
  /// 例如填写 `/reports` 只保护 `/reports` 本身，不会自动保护
  /// `/reports/detail`。适合只有一个独立页面需要认证的场景。
  ///
  /// 这里比较的是 GoRouter 的 `matchedLocation`，不会把 query 参数当成路径。
  /// 公开页面不要加入该列表。构造函数会校验每项并复制为不可变列表。
  final List<String> protectedPaths;

  /// 需要登录的“路径树前缀”列表。
  ///
  /// 例如填写 `/workspace` 会保护：
  /// - `/workspace`；
  /// - `/workspace/home`；
  /// - `/workspace/orders/123`。
  ///
  /// 它不会误匹配 `/workspace2`，因为守卫只接受前缀本身或紧随 `/` 的子路径。
  /// 当一个业务模块的全部页面都要求登录时，优先使用本字段，避免每新增详情页
  /// 都忘记更新 [protectedPaths]。构造函数会校验每项并复制为不可变列表。
  final List<String> protectedPrefixes;
}
