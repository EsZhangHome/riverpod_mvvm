import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/utils/crash_reporter.dart';
import 'package:riverpod_mvvm/core/utils/logger.dart';

void main() {
  tearDown(() {
    AppLogger.configure(const NoopLogSink());
    CrashReporter.configure(const DebugCrashReportingBackend());
  });

  test('logging backend failure never breaks business flow', () {
    AppLogger.configure(_ThrowingLogSink());

    expect(() => AppLogger.info('business event'), returnsNormally);
  });

  test('crash reporting backend failure is contained', () {
    AppLogger.configure(const NoopLogSink());
    CrashReporter.configure(_ThrowingCrashBackend());

    expect(
      () => CrashReporter.report(StateError('original'), StackTrace.current),
      returnsNormally,
    );
    expect(() => CrashReporter.setContext('userId', '1'), returnsNormally);
    expect(() => CrashReporter.addBreadcrumb('open page'), returnsNormally);
  });
}

class _ThrowingLogSink implements LogSink {
  @override
  void write(LogRecord record) => throw StateError('log sdk unavailable');
}

class _ThrowingCrashBackend implements CrashReportingBackend {
  @override
  void addBreadcrumb(String message, {Map<String, Object?> data = const {}}) {
    throw StateError('crash sdk unavailable');
  }

  @override
  void capture(Object error, StackTrace? stack, {bool fatal = false}) {
    throw StateError('crash sdk unavailable');
  }

  @override
  Future<void> initialize() async {}

  @override
  void setContext(String key, Object? value) {
    throw StateError('crash sdk unavailable');
  }
}
