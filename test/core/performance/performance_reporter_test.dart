import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/performance/performance_reporter.dart';
import 'package:riverpod_mvvm/core/utils/logger.dart';

void main() {
  tearDown(() {
    AppPerformance.configure(const NoopPerformanceReporter());
    AppLogger.configure(const NoopLogSink());
  });

  test('measure records elapsed metric and returns business result', () async {
    final reporter = _CollectingReporter();
    AppPerformance.configure(reporter);

    final result = await AppPerformance.measure(
      'repository.load',
      () async => 42,
      attributes: const {'source': 'memory'},
    );

    expect(result, 42);
    expect(reporter.metrics.single.name, 'repository.load');
    expect(reporter.metrics.single.attributes, {'source': 'memory'});
  });

  test('reporter failure never breaks measured business action', () async {
    AppLogger.configure(const NoopLogSink());
    AppPerformance.configure(_ThrowingReporter());

    final result = await AppPerformance.measure('request', () async => 'ok');

    expect(result, 'ok');
  });
}

final class _CollectingReporter implements PerformanceReporter {
  final metrics = <PerformanceMetric>[];

  @override
  void record(PerformanceMetric metric) => metrics.add(metric);
}

final class _ThrowingReporter implements PerformanceReporter {
  @override
  void record(PerformanceMetric metric) {
    throw StateError('performance sdk unavailable');
  }
}
