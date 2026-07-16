import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/bootstrap/app_bootstrap.dart';

void main() {
  test('all bootstrap stages succeed', () async {
    final bootstrap = AppBootstrap(
      validateConfiguration: () {},
      initializeStorage: () async {},
    );

    final result = await bootstrap.initialize();

    expect(result.status, BootstrapStatus.ready);
    expect(result.canStart, isTrue);
    expect(result.issues, isEmpty);
  });

  test('configuration error blocks application startup', () async {
    final bootstrap = AppBootstrap(
      validateConfiguration: () => throw StateError('unsafe config'),
      initializeStorage: () async {},
    );

    final result = await bootstrap.initialize();

    expect(result.status, BootstrapStatus.failed);
    expect(result.canStart, isFalse);
    expect(result.issues.single.stage, 'configuration');
    expect(result.issues.single.isCritical, isTrue);
  });

  test('infrastructure error starts in degraded mode', () async {
    final bootstrap = AppBootstrap(
      validateConfiguration: () {},
      initializeStorage: () async => throw StateError('storage unavailable'),
    );

    final result = await bootstrap.initialize();

    expect(result.status, BootstrapStatus.degraded);
    expect(result.canStart, isTrue);
    expect(result.issues.single.stage, 'storage');
    expect(result.issues.single.isCritical, isFalse);
  });

  test('hung infrastructure stage times out and starts degraded', () async {
    final bootstrap = AppBootstrap(
      validateConfiguration: () {},
      initializeStorage: () => Future<void>.delayed(const Duration(seconds: 1)),
      stageTimeout: const Duration(milliseconds: 10),
    );

    final result = await bootstrap.initialize();

    expect(result.status, BootstrapStatus.degraded);
    expect(result.issues.single.error, isA<TimeoutException>());
  });
}
