// test/core/network/unauthorized_guard_test.dart
//
// 401 防抖测试：并发接口同时返回未授权时只执行一次退出；新登录会话通过 reset
// 重新开放守卫。这里测试并发控制，不启动 Dio 拦截器链。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/dio_interceptor.dart';

void main() {
  test(
    'unauthorized guard only handles one unauthorized event at a time',
    () async {
      // Arrange：计数器代表真正的 AuthNotifier.logout 调用。
      var count = 0;
      final guard = UnauthorizedGuard(onUnauthorized: () async => count++);

      // Act：三个并发 401 同时进入同一个 guard。
      await Future.wait([guard.handle(), guard.handle(), guard.handle()]);

      // Assert：只允许首个事件执行退出。
      expect(count, 1);
    },
  );

  test(
    'unauthorized guard can be reset after a new login session starts',
    () async {
      var count = 0;
      final guard = UnauthorizedGuard(onUnauthorized: () async => count++);

      // 第一段会话已经处理过 401；reset 模拟用户重新登录。
      await guard.handle();
      guard.reset();
      await guard.handle();

      expect(count, 2);
    },
  );
}
