// Demo 专属路径。企业底座内置路径位于 shared/navigation/route_paths.dart。
// 这些路径只存在于独立示例应用，企业底座 RoutePaths 不会留下案例地址。

abstract final class DemoRoutePaths {
  static const String main = '/main';
  static const String mainHome = '/main/home';
  static const String cartSegment = 'cart';
  static const String mainCart = '$mainHome/$cartSegment';
  static const String mainOrders = '/main/orders';
  static const String mainMine = '/main/mine';
  static const String riverpodLearning = '/riverpod-learning';
}
