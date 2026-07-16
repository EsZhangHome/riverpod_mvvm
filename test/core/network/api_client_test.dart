import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/api_client.dart';
import 'package:riverpod_mvvm/core/network/api_exception.dart';
import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import 'package:riverpod_mvvm/core/network/request_context.dart';
import 'package:riverpod_mvvm/core/utils/logger.dart';

void main() {
  setUp(() => AppLogger.configure(const NoopLogSink()));

  test('updating auth callbacks keeps one stable interceptor chain', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final adapter = _RecordingAdapter();
    dio.httpClientAdapter = adapter;
    final client = ApiClient(dio: dio);
    addTearDown(client.close);
    final originalInterceptors = List<Interceptor>.of(dio.interceptors);

    client
      ..setTokenProvider(() => 'new-token')
      ..setUnauthorizedCallback(() async {})
      ..setTokenRefreshCallback(() async => 'refreshed-token');

    expect(dio.interceptors, orderedEquals(originalInterceptors));
    await client.get<Map<String, dynamic>>(
      '/resource',
      fromJson: (json) => Map<String, dynamic>.from(json as Map),
    );
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer new-token',
    );
  });

  test(
    'upload is marked as never replayable even without request context',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _RecordingAdapter();
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio: dio);
      addTearDown(client.close);
      final directory = await Directory.systemTemp.createTemp(
        'api_client_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/attachment.txt');
      await file.writeAsString('content');

      await client.upload<Map<String, dynamic>>(
        '/attachments',
        filePath: file.path,
        fromJson: (json) => Map<String, dynamic>.from(json as Map),
      );

      expect(adapter.requests.single.extra['replayDisabled'], isTrue);
    },
  );

  test('network logs omit URL credentials and query values', () async {
    final sink = _CollectingLogSink();
    AppLogger.configure(sink);
    final dio = Dio(
      BaseOptions(baseUrl: 'https://api-user:api-secret@api.test'),
    );
    dio.httpClientAdapter = _RecordingAdapter();
    final client = ApiClient(dio: dio);
    addTearDown(client.close);

    await client.get<Map<String, dynamic>>(
      '/customers',
      queryParameters: {'phone': '13800138000'},
      fromJson: (json) => Map<String, dynamic>.from(json as Map),
    );

    final messages = sink.records.map((record) => record.message).join('\n');
    expect(messages, contains('https://api.test/customers'));
    expect(messages, isNot(contains('api-secret')));
    expect(messages, isNot(contains('13800138000')));
  });

  test(
    'framework cancellation token stops the underlying Dio request',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _BlockingAdapter();
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio: dio);
      addTearDown(client.close);
      final cancellation = RequestCancellationToken();

      final request = client.get<Map<String, dynamic>>(
        '/slow',
        cancelToken: cancellation,
        fromJson: (json) => Map<String, dynamic>.from(json as Map),
      );
      await adapter.started.future;
      cancellation.cancel('route disposed');

      await expectLater(
        request,
        throwsA(
          isA<ApiException>().having(
            (error) => error.isCancelled,
            'isCancelled',
            true,
          ),
        ),
      );
    },
  );

  test(
    'concurrent 401 responses refresh once and replay both requests',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _UnauthorizedThenSuccessAdapter(expectedInitialCount: 2);
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio: dio);
      addTearDown(client.close);

      var accessToken = 'expired-token';
      var refreshCount = 0;
      var unauthorizedCount = 0;
      final refreshGate = Completer<String>();
      final refreshStarted = Completer<void>();
      client
        ..setTokenProvider(() => accessToken)
        ..setUnauthorizedCallback(() async => unauthorizedCount++)
        ..setTokenRefreshCallback(() async {
          refreshCount++;
          if (!refreshStarted.isCompleted) refreshStarted.complete();
          final refreshedToken = await refreshGate.future;
          // 真实认证模块也必须先持久化/更新内存 token，再把它返回给网络层。
          // 这样重放请求再次经过 TokenInterceptor 时读到的仍是新 token。
          accessToken = refreshedToken;
          return refreshedToken;
        });

      final requests = [
        client.get<Map<String, dynamic>>('/orders', fromJson: _decodeMap),
        client.get<Map<String, dynamic>>('/profile', fromJson: _decodeMap),
      ];
      await adapter.allInitialRequestsArrived.future;
      await refreshStarted.future;
      expect(refreshCount, 1);
      refreshGate.complete('refreshed-token');

      final responses = await Future.wait(requests);
      expect(
        responses.map((response) => response.data?['ok']),
        everyElement(true),
      );
      expect(refreshCount, 1);
      expect(unauthorizedCount, 0);
      expect(adapter.attempts, hasLength(4));
      expect(
        adapter.attempts.where((attempt) => attempt.authRetried),
        hasLength(2),
      );
      expect(
        adapter.attempts
            .where((attempt) => attempt.authRetried)
            .map((attempt) => attempt.authorization),
        everyElement('Bearer refreshed-token'),
      );
    },
  );

  test(
    'never-replay request refreshes token but does not resend body',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _UnauthorizedThenSuccessAdapter(expectedInitialCount: 1);
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio: dio);
      addTearDown(client.close);

      var refreshCount = 0;
      var unauthorizedCount = 0;
      client
        ..setTokenProvider(() => 'expired-token')
        ..setUnauthorizedCallback(() async => unauthorizedCount++)
        ..setTokenRefreshCallback(() async {
          refreshCount++;
          return 'refreshed-token';
        });

      await expectLater(
        client.post<Map<String, dynamic>>(
          '/payments',
          data: {'amount': 100},
          context: const RequestContext(
            replayPolicy: RequestReplayPolicy.never,
          ),
          fromJson: _decodeMap,
        ),
        throwsA(isA<ApiException>()),
      );

      // 刷新结果会供下一次由业务重新构造的请求使用，但支付 body 绝不能悄悄发送两次。
      expect(refreshCount, 1);
      expect(unauthorizedCount, 0);
      expect(adapter.attempts, hasLength(1));
    },
  );

  test(
    'write request is not retried when idempotency key is missing',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _ConnectionFailureThenSuccessAdapter(failureCount: 1);
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio: dio);
      addTearDown(client.close);

      await expectLater(
        client.post<Map<String, dynamic>>(
          '/orders',
          data: {'sku': 'A-001'},
          context: const RequestContext(allowRetry: true),
          fromJson: _decodeMap,
        ),
        throwsA(isA<ApiException>()),
      );

      expect(adapter.attempts, 1);
    },
  );

  test(
    'idempotent write keeps the same key when connection retry occurs',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _ConnectionFailureThenSuccessAdapter(failureCount: 1);
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio: dio);
      addTearDown(client.close);

      final response = await client.post<Map<String, dynamic>>(
        '/orders',
        data: {'sku': 'A-001'},
        context: const RequestContext(
          allowRetry: true,
          idempotencyKey: 'create-order-operation-001',
        ),
        fromJson: _decodeMap,
      );

      expect(response.data?['ok'], isTrue);
      expect(adapter.attempts, 2);
      expect(
        adapter.idempotencyKeys,
        everyElement('create-order-operation-001'),
      );
    },
  );
}

Map<String, dynamic> _decodeMap(dynamic json) {
  return Map<String, dynamic>.from(json as Map);
}

/// 不访问网络的 Dio 适配器，同时保留最终 RequestOptions 供断言拦截器结果。
final class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"code":0,"message":"ok","data":{"ok":true}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _CollectingLogSink implements LogSink {
  final records = <LogRecord>[];

  @override
  void write(LogRecord record) => records.add(record);
}

/// 模拟永不主动返回的底层连接，只在 Dio 收到 cancelFuture 后结束。
final class _BlockingAdapter implements HttpClientAdapter {
  final Completer<void> started = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started.complete();
    await cancelFuture;
    throw DioException.requestCancelled(
      requestOptions: options,
      reason: 'adapter cancelled',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 第一次发送统一返回 401；带 authRetried 标记的重放请求返回成功。
///
/// 适配器记录不可变快照而不是保存 RequestOptions 引用，因为重放流程会修改原对象的
/// header/extra。若直接保存引用，测试看到的“第一次请求”也会被后续修改污染。
final class _UnauthorizedThenSuccessAdapter implements HttpClientAdapter {
  _UnauthorizedThenSuccessAdapter({required this.expectedInitialCount});

  final int expectedInitialCount;
  final attempts = <_RequestAttempt>[];
  final Completer<void> allInitialRequestsArrived = Completer<void>();
  int _initialCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final authRetried = options.extra['authRetried'] == true;
    attempts.add(
      _RequestAttempt(
        authRetried: authRetried,
        authorization: options.headers['Authorization']?.toString(),
      ),
    );
    if (!authRetried) {
      _initialCount++;
      if (_initialCount == expectedInitialCount &&
          !allInitialRequestsArrived.isCompleted) {
        allInitialRequestsArrived.complete();
      }
      return _jsonResponse(401, data: const {'ok': false});
    }
    return _jsonResponse(200, data: const {'ok': true});
  }

  @override
  void close({bool force = false}) {}
}

final class _RequestAttempt {
  const _RequestAttempt({
    required this.authRetried,
    required this.authorization,
  });

  final bool authRetried;
  final String? authorization;
}

/// 用连接错误模拟移动网络瞬断，随后返回成功。
final class _ConnectionFailureThenSuccessAdapter implements HttpClientAdapter {
  _ConnectionFailureThenSuccessAdapter({required this.failureCount});

  final int failureCount;
  int attempts = 0;
  final idempotencyKeys = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    attempts++;
    idempotencyKeys.add(options.headers['Idempotency-Key']?.toString());
    if (attempts <= failureCount) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'simulated temporary connection failure',
        error: const SocketException('simulated offline'),
      );
    }
    return _jsonResponse(200, data: const {'ok': true});
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int statusCode, {required Map<String, bool> data}) {
  final ok = data['ok'] == true;
  return ResponseBody.fromString(
    '{"code":${statusCode == 200 ? 0 : statusCode},'
    '"message":"${ok ? 'ok' : 'unauthorized'}",'
    '"data":{"ok":$ok}}',
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
