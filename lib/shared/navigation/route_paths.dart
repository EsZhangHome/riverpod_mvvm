// lib/shared/navigation/route_paths.dart
//
// 作用：集中管理所有路由路径常量，避免字符串散落在各页面和路由守卫中。
//
// 设计要点：
// 1. 所有路径使用 static const，编译时常量，零运行时开销
// 2. 私有构造函数防止实例化，这个类只作为常量容器
// 3. 路径片段统一使用小写；多单词路径的连接方式由项目路由规范统一约定
//
// 路由结构：
// /login            → 登录页
// /splash           → 登录态恢复页
// /starter          → 等待真实项目替换的起始页

/// 路由路径集中管理。
///
/// 底座内置路由结构：
/// /login            → 登录页
/// /splash           → 启动页（恢复登录态时）
/// /starter          → 尚未接入真实首页时的受保护占位页
class RoutePaths {
  const RoutePaths._();

  /// 登录页路径。
  static const String login = '/login';

  /// 启动页路径（恢复登录态期间展示）。
  static const String splash = '/splash';

  /// 新项目尚未接入真实业务首页时使用的默认受保护页面。
  static const String starter = '/starter';
}
