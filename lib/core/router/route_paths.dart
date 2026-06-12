// lib/core/router/route_paths.dart
//
// 作用：集中管理所有路由路径常量，避免字符串散落在各页面和路由守卫中。
//
// 设计要点：
// 1. 所有路径使用 static const，编译时常量，零运行时开销
// 2. 私有构造函数防止实例化，这个类只作为常量容器
// 3. 路径命名采用小写+下划线风格，与 URL 规范一致
// 4. home 是 main 的别名，方便业务代码使用语义化的路径名
//
// 路由结构：
// /login            → 登录页
// /main             → 主框架页（包含底部 Tab）
// /main/home        → 主页 Tab（进入 MainPage 时默认选中首页）
// /main/community   → 社区 Tab
// /main/mine        → 我的 Tab

/// 路由路径集中管理。
///
/// 路由结构（StatefulShellRoute）：
/// /login            → 登录页
/// /splash           → 启动页（恢复登录态时）
/// /main             → StatefulShellRoute 外壳（自动重定向到 /main/home）
///   /main/home      → 首页 Tab
///   /main/community → 社区 Tab
///   /main/mine      → 我的 Tab
class RoutePaths {
  const RoutePaths._();

  /// 登录页路径。
  static const String login = '/login';

  /// 启动页路径（恢复登录态期间展示）。
  static const String splash = '/splash';

  /// 主框架外壳路径。StatefulShellRoute 的父路径，自动解析到第一个分支。
  static const String main = '/main';

  /// /main 的别名。
  static const String home = main;

  /// 首页 Tab 路径。
  static const String mainHome = '/main/home';

  /// 社区 Tab 路径。
  static const String mainCommunity = '/main/community';

  /// 我的 Tab 路径。
  static const String mainMine = '/main/mine';
}
