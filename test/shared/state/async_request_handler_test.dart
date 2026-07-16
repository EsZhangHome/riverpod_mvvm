// AsyncRequestHandler 生命周期测试。
//
// Handler 不依赖 Widget 或 ProviderContainer，因此直接验证请求、状态回调、
// 防重复和 CancelToken；Notifier 测试只需关注业务状态组合。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/shared/state/async_request_handler.dart';
import 'package:riverpod_mvvm/core/network/api_exception.dart';

void main() {
  test('successful request calls loading and success in order', () async {
    final handler = AsyncRequestHandler();
    addTearDown(handler.dispose);
    final events = <String>[];

    final result = await handler.execute<int>(
      request: () async => 7,
      onLoading: () => events.add('loading'),
      onSuccess: () => events.add('success'),
      onError: (message) => events.add('error:$message'),
    );

    expect(result, 7);
    expect(events, ['loading', 'success']);
  });

  test('empty result uses onEmpty instead of onSuccess', () async {
    final handler = AsyncRequestHandler();
    addTearDown(handler.dispose);
    final events = <String>[];

    await handler.execute<List<int>>(
      request: () async => const [],
      onLoading: () {},
      onSuccess: () => events.add('success'),
      onEmpty: () => events.add('empty'),
      onError: (_) {},
      isEmpty: (items) => items.isEmpty,
    );

    expect(events, ['empty']);
  });

  test('second request is ignored while the first request is active', () async {
    final handler = AsyncRequestHandler();
    addTearDown(handler.dispose);
    final completer = Completer<int>();
    var requestCount = 0;

    final first = handler.execute<int>(
      request: () {
        requestCount++;
        return completer.future;
      },
      onLoading: () {},
      onSuccess: () {},
      onError: (_) {},
    );
    final second = await handler.execute<int>(
      request: () async {
        requestCount++;
        return 2;
      },
      onLoading: () {},
      onSuccess: () {},
      onError: (_) {},
    );

    expect(second, isNull);
    expect(requestCount, 1);
    completer.complete(1);
    expect(await first, 1);
  });

  test('dispose cancels token and suppresses late state callbacks', () async {
    final handler = AsyncRequestHandler();
    final resultCompleter = Completer<int>();
    final events = <String>[];

    final request = handler.execute<int>(
      request: () => resultCompleter.future,
      onLoading: () => events.add('loading'),
      onSuccess: () => events.add('success'),
      onError: (message) => events.add('error:$message'),
    );
    handler.dispose();
    resultCompleter.complete(1);

    expect(await request, isNull);
    expect(handler.cancelToken.isCancelled, isTrue);
    expect(events, ['loading']);
  });

  test('business and unknown errors are converted to safe messages', () async {
    final handler = AsyncRequestHandler();
    addTearDown(handler.dispose);
    final messages = <String>[];

    await handler.execute<void>(
      request: () => throw BusinessException(code: 1, userMessage: '余额不足'),
      onLoading: () {},
      onSuccess: () {},
      onError: messages.add,
    );
    await handler.execute<void>(
      request: () => throw StateError('internal details'),
      onLoading: () {},
      onSuccess: () {},
      onError: messages.add,
    );
    await handler.execute<void>(
      request: () => throw BusinessException(
        code: 2,
        userMessage: 'database host: private.internal',
        canDisplayMessage: false,
      ),
      onLoading: () {},
      onSuccess: () {},
      onError: messages.add,
    );

    expect(messages, ['余额不足', '请求失败，请稍后重试', '请求失败，请稍后重试']);
  });
}
