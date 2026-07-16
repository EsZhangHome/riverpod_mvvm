import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/request_cancellation.dart';

void main() {
  test('cancel completes the signal once and keeps the first reason', () async {
    final token = RequestCancellationToken();

    expect(token.isCancelled, isFalse);
    token.cancel('page disposed');
    token.cancel('second reason');

    expect(token.isCancelled, isTrue);
    expect(token.reason, 'page disposed');
    expect(await token.whenCancelled, 'page disposed');
  });

  test('cancellation failure uses the stable AppFailure category', () {
    const failure = RequestCancellationFailure('test');

    expect(failure.isCancellation, isTrue);
    expect(failure.cause, 'test');
  });

  test('disposed listener no longer receives cancellation', () {
    final token = RequestCancellationToken();
    Object? receivedReason;
    final registration = token.listen((reason) => receivedReason = reason);

    registration.dispose();
    registration.dispose();
    token.cancel('finished request');

    expect(receivedReason, isNull);
  });
}
