// test/core/network/unauthorized_guard_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_mvvm/core/network/dio_interceptor.dart';

void main() {
  test('unauthorized guard only handles one unauthorized event at a time', () {
    var count = 0;
    final guard = UnauthorizedGuard(onUnauthorized: () => count++);

    guard.handle();
    guard.handle();
    guard.handle();

    expect(count, 1);
  });

  test('unauthorized guard can be reset after a new login session starts', () {
    var count = 0;
    final guard = UnauthorizedGuard(onUnauthorized: () => count++);

    guard.handle();
    guard.reset();
    guard.handle();

    expect(count, 2);
  });
}
