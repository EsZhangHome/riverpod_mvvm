// AppRouteBundle 入口约束测试。
//
// 路由配置只在 App 启动时创建一次，越早拒绝外部 URL、带 query 的“伪路径”和后续
// 原地修改，越不容易把配置错误拖到用户点击某个页面后才暴露。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/navigation/app_route_bundle.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';

void main() {
  test('route bundle accepts internal paths and freezes protection lists', () {
    final protectedPaths = <String>['/settings'];
    final bundle = AppRouteBundle(
      authenticatedHome: '/home',
      protectedPaths: protectedPaths,
      protectedPrefixes: const ['/orders'],
    );

    // 构造完成后修改调用方原 List，不能悄悄改变正在运行的守卫配置。
    protectedPaths.add('/admin');
    expect(bundle.protectedPaths, ['/settings']);
    expect(() => bundle.protectedPaths.add('/other'), throwsUnsupportedError);
  });

  test('route bundle rejects external or non-path route declarations', () {
    for (final invalidPath in [
      '',
      'home',
      'https://example.com/home',
      '//example.com/home',
      '/home?tab=1',
      '/home#section',
    ]) {
      expect(
        () => AppRouteBundle(authenticatedHome: invalidPath),
        throwsArgumentError,
        reason: '$invalidPath is not a pure internal path',
      );
    }
  });

  test('route bundle reserves login and session restoring boundaries', () {
    expect(
      () => AppRouteBundle(
        authenticatedHome: RoutePaths.login,
        loginPath: RoutePaths.login,
      ),
      throwsArgumentError,
    );
    expect(
      () => AppRouteBundle(authenticatedHome: RoutePaths.sessionRestoring),
      throwsArgumentError,
    );
  });
}
