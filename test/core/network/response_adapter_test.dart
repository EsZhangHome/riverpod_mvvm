import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/response_adapter.dart';

void main() {
  Response<dynamic> response(dynamic data, {int statusCode = 200}) => Response(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: '/resource'),
  );

  test('envelope adapter decodes business envelope', () {
    const adapter = EnvelopeResponseAdapter(successCode: 0);

    final result = adapter.adapt<Map<String, Object?>>(
      response({
        'code': 0,
        'message': 'ok',
        'data': {'id': 7},
      }),
      (json) => Map<String, Object?>.from(json as Map),
    );

    expect(result.isSuccess, isTrue);
    expect(result.data, {'id': 7});
    expect(result.canDisplayMessage, isFalse);
  });

  test('business message is displayable only when explicitly trusted', () {
    const adapter = EnvelopeResponseAdapter(trustBusinessMessage: true);

    final result = adapter.adapt<void>(
      response({'code': 1001, 'message': '账号已冻结', 'data': null}),
      null,
    );

    expect(result.isSuccess, isFalse);
    expect(result.canDisplayMessage, isTrue);
  });

  test('envelope adapter also supports plain REST payload', () {
    const adapter = EnvelopeResponseAdapter();

    final result = adapter.adapt<List<int>>(
      response([1, 2, 3]),
      (json) => List<int>.from(json as List),
    );

    expect(result.isSuccess, isTrue);
    expect(result.data, [1, 2, 3]);
  });

  test('HTTP status mode can ignore nonstandard business success code', () {
    const adapter = EnvelopeResponseAdapter(useHttpStatus: true);

    final result = adapter.adapt<String>(
      response({'code': 9001, 'message': 'accepted', 'data': 'done'}),
      (json) => json as String,
    );

    expect(result.isSuccess, isTrue);
    expect(result.data, 'done');
  });

  test('direct adapter returns response body without envelope assumption', () {
    const adapter = DirectResponseAdapter();
    final result = adapter.adapt<int>(response(42), (json) => json as int);

    expect(result.isSuccess, isTrue);
    expect(result.data, 42);
  });
}
