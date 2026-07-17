// test/app/navigation/route_paths_test.dart
// 路径常量契约测试：集中路径发生变化时，测试会提醒同步深链和路由配置。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';

void main() {
  test('route paths contain only universal framework infrastructure', () {
    expect(RoutePaths.login, '/login');
    expect(RoutePaths.sessionRestoring, '/session-restoring');
    expect(RoutePaths.privacyCenter, '/privacy-center');
  });
}
