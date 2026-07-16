import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm_demo/navigation/demo_route_paths.dart';

void main() {
  test('demo route paths are isolated from starter framework paths', () {
    expect(DemoRoutePaths.main, '/main');
    expect(DemoRoutePaths.mainHome, '/main/home');
    expect(DemoRoutePaths.mainCart, '/main/home/cart');
    expect(DemoRoutePaths.mainOrders, '/main/orders');
    expect(DemoRoutePaths.mainMine, '/main/mine');
    expect(DemoRoutePaths.riverpodLearning, '/riverpod-learning');
  });
}
