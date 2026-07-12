// test/core/network/unauthorized_guard_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/dio_interceptor.dart';

void main() {
  test(
    'unauthorized guard only handles one unauthorized event at a time',
    () async {
      var count = 0;
      final guard = UnauthorizedGuard(onUnauthorized: () async => count++);

      await Future.wait([guard.handle(), guard.handle(), guard.handle()]);

      expect(count, 1);
    },
  );

  test(
    'unauthorized guard can be reset after a new login session starts',
    () async {
      var count = 0;
      final guard = UnauthorizedGuard(onUnauthorized: () async => count++);

      await guard.handle();
      guard.reset();
      await guard.handle();

      expect(count, 2);
    },
  );
}
