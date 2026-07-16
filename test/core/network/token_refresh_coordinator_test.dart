import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/token_refresh_coordinator.dart';

void main() {
  test(
    'concurrent unauthorized requests share one refresh operation',
    () async {
      final coordinator = TokenRefreshCoordinator();
      final completer = Completer<String?>();
      var refreshCount = 0;

      Future<String?> refresh() {
        refreshCount++;
        return completer.future;
      }

      final first = coordinator.run(refresh);
      final second = coordinator.run(refresh);
      completer.complete('new-token');

      expect(await Future.wait([first, second]), ['new-token', 'new-token']);
      expect(refreshCount, 1);
    },
  );

  test('a completed refresh does not block the next session', () async {
    final coordinator = TokenRefreshCoordinator();
    var refreshCount = 0;

    Future<String?> refresh() async => 'token-${++refreshCount}';

    expect(await coordinator.run(refresh), 'token-1');
    expect(await coordinator.run(refresh), 'token-2');
  });
}
