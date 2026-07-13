// lib/core/router/route_paths.dart
//
// 作用：集中管理所有路由路径常量，避免字符串散落在各页面和路由守卫中。
//
// 设计要点：
// 1. 所有路径使用 static const，编译时常量，零运行时开销
// 2. 私有构造函数防止实例化，这个类只作为常量容器
// 3. 路径命名采用小写+下划线风格，与 URL 规范一致
// 4. home 是 mainHome 的语义别名，始终指向真实可匹配路由
//
// 路由结构：
// /login            → 登录页
// /main             → 兼容入口（重定向到 /main/home）
// /main/home        → 商品 Tab（进入 MainPage 时默认选中）
// /main/home/cart   → 购物车详情
// /main/orders      → 订单 Tab
// /main/mine        → 我的与设置 Tab
// /riverpod-learning → 独立 Riverpod 学习中心

/// 路由路径集中管理。
///
/// 路由结构（StatefulShellRoute）：
/// /login            → 登录页
/// /splash           → 启动页（恢复登录态时）
/// /riverpod-learning → 独立 Riverpod 学习中心
/// /main             → 兼容入口（显式重定向到 /main/home）
///   /main/home   → 商品 Tab
///     /main/home/cart → 购物车详情
///   /main/orders → 订单 Tab
///   /main/mine   → 我的与设置 Tab
class RoutePaths {
  const RoutePaths._();

  /// 登录页路径。
  static const String login = '/login';

  /// 启动页路径（恢复登录态期间展示）。
  static const String splash = '/splash';

  /// 主框架兼容入口，AppRouter 会把它重定向到第一个分支。
  static const String main = '/main';

  /// 商品 Tab 路径。
  static const String mainHome = '/main/home';

  /// 商品分支中的购物车子路由片段。
  static const String cartSegment = 'cart';

  /// 购物车详情完整路径。
  static const String mainCart = '$mainHome/$cartSegment';

  /// 首页语义别名，始终指向一个真实可匹配的路由。
  static const String home = mainHome;

  /// 订单 Tab 路径。
  static const String mainOrders = '/main/orders';

  /// 我的 Tab 路径。
  static const String mainMine = '/main/mine';

  /// 从“我的”页面进入的独立 Riverpod 学习中心。
  static const String riverpodLearning = '/riverpod-learning';
}
