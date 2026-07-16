import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/database/database_exception.dart';
import 'package:riverpod_mvvm/core/errors/failure_observer.dart';
import 'package:riverpod_mvvm/core/network/api_exception.dart';
import 'package:riverpod_mvvm/core/utils/crash_reporter.dart';
import 'package:riverpod_mvvm/shared/errors/failure_message_resolver.dart';
import 'package:riverpod_mvvm/shared/localization/user_message.dart';

final class _CaptureBackend implements CrashReportingBackend {
  Object? error;
  StackTrace? stackTrace;
  var captureCount = 0;

  @override
  void capture(Object error, StackTrace? stack, {bool fatal = false}) {
    captureCount++;
    this.error = error;
    stackTrace = stack;
  }

  @override
  Future<void> initialize() async {}

  @override
  void setContext(String key, Object? value) {}

  @override
  void addBreadcrumb(String message, {Map<String, Object?> data = const {}}) {}
}

void main() {
  late _CaptureBackend backend;

  setUp(() {
    backend = _CaptureBackend();
    CrashReporter.configure(backend);
  });
  tearDown(() => CrashReporter.configure(const DebugCrashReportingBackend()));

  test('protocol failure reports its original cause and stack', () {
    final cause = FormatException('invalid response shape');
    final originalStack = StackTrace.current;
    final failure = ApiException.protocol(cause, originalStack);

    FailureObserver.reportIfNeeded(failure, StackTrace.empty);

    expect(backend.captureCount, 1);
    expect(backend.error, same(cause));
    expect(backend.stackTrace, same(originalStack));
  });

  test('database failure is classified as storage and remains observable', () {
    final cause = StateError('disk unavailable');
    final originalStack = StackTrace.current;
    final failure = DatabaseException(
      '查询数据失败',
      cause: cause,
      stackTrace: originalStack,
    );

    FailureObserver.reportIfNeeded(failure, StackTrace.empty);

    expect(failure.shouldReport, isTrue);
    expect(
      FailureMessageResolver.resolve(failure).key,
      UserMessageKey.storageError,
    );
    expect(backend.error, same(cause));
    expect(backend.stackTrace, same(originalStack));
  });

  test('expected business failure does not create monitoring noise', () {
    final failure = BusinessException(code: 1001, userMessage: '余额不足');

    FailureObserver.reportIfNeeded(failure, StackTrace.current);

    expect(backend.captureCount, 0);
  });
}
