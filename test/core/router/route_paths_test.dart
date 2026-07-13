// test/core/router/route_paths_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/router/route_paths.dart';

void main() {
  test('main tab route paths are centralized', () {
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
