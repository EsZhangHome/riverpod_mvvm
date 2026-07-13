// test/core/router/route_paths_test.dart
// 路径常量契约测试：集中路径发生变化时，测试会提醒同步深链和路由配置。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/router/route_paths.dart';

void main() {
  test('main tab route paths are centralized', () {
    // 根页面、Tab、购物车与学习中心必须由 RoutePaths 提供唯一来源。
    expect(RoutePaths.login, '/login');
    expect(RoutePaths.main, '/main');
    expect(RoutePaths.mainHome, '/main/home');
    expect(RoutePaths.mainCart, '/main/home/cart');
    expect(RoutePaths.home, RoutePaths.mainHome);
    expect(RoutePaths.mainOrders, '/main/orders');
    expect(RoutePaths.mainMine, '/main/mine');
    expect(RoutePaths.riverpodLearning, '/riverpod-learning');
  });
}
