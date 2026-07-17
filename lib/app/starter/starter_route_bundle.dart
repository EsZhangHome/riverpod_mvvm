// 尚未接入真实业务时使用的完整占位路由组件。
//
// Starter 的路径、页面、登录保护和路由注册都保存在本目录，通用 AppRouter、
// AuthRouteGuard 与 RoutePaths 不知道它的存在。这样真实项目删除 Starter 时，不需要
// 清理通用底座中的残留判断。

import 'package:go_router/go_router.dart';

import '../navigation/app_route_bundle.dart';
import 'starter_home_page.dart';

/// Starter 组件内部拥有的路径。
///
/// 路径不放进 shared/RoutePaths，因为它不是所有企业项目都必须保留的基础设施。
/// 外部代码也不应依赖这个常量；接入真实业务后应整体删除 Starter 组件。
abstract final class StarterRoutePaths {
  static const home = '/starter';
}

/// 创建“底座刚克隆下来即可运行”的占位路由包。
///
/// 返回的 [AppRouteBundle] 包含完整闭环：
/// - 登录后的首页地址为 `/starter`；
/// - routes 中真正注册 [StarterHomePage]；
/// - authenticatedHome 会被通用认证守卫自动保护，因此这里无需重复声明。
///
/// 本函数故意不做成 `AppRouteBundle.starter()`：如果工厂留在通用路由契约中，
/// AppRouteBundle 就必须长期认识占位页面。现在 main.dart 只通过 Starter 公共入口
/// 获得路由和开发依赖组合；替换成项目实现后，整个 starter 目录可以直接删除。
AppRouteBundle createStarterRouteBundle() {
  return AppRouteBundle(
    authenticatedHome: StarterRoutePaths.home,
    routes: [
      GoRoute(
        path: StarterRoutePaths.home,
        builder: (context, state) => const StarterHomePage(),
      ),
    ],
  );
}
