import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/api_client.dart';
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
      // 文件传输时长主要由文件大小决定，不应污染普通 JSON 接口的弱网判断。
      expect(adapter.requests.single.extra['networkQualityExcluded'], isTrue);
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
