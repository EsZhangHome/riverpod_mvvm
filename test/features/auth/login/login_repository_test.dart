// 真实登录 Repository 测试。
//
// 测试环境的 ENV_ENABLE_MOCK 默认是 true；本测试仍要求 RemoteLoginRepository 调用
// FakeApiService，用来证明真实实现内部已经没有编译期开关和 Mock 分支。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/api_exception.dart';
import 'package:riverpod_mvvm/core/network/api_response.dart';
import 'package:riverpod_mvvm/core/network/api_service.dart';
import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import 'package:riverpod_mvvm/core/network/request_context.dart';
import 'package:riverpod_mvvm/features/auth/login/model/login_request.dart';
import 'package:riverpod_mvvm/features/auth/login/repository/login_repository.dart';

final class _FakeApiService implements ApiService {
  String? receivedPath;
  Object? receivedData;
  RequestCancellationToken? receivedCancellation;
  bool returnEmptyData = false;

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    RequestCancellationToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  }) async {
    receivedPath = path;
    receivedData = data;
    receivedCancellation = cancelToken;
    if (returnEmptyData) {
      return ApiResponse<T>(code: 0, message: 'success', successOverride: true);
    }
    final result = fromJson!({
      'token': 'remote-token',
      'user': {
        'id': 'remote-user',
        'name': 'Remote User',
        'email': 'remote@example.com',
      },
    });
    return ApiResponse<T>(
      code: 0,
      message: 'success',
      data: result,
      successOverride: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'remote repository always calls ApiService and forwards cancellation',
    () async {
      final api = _FakeApiService();
      final repository = RemoteLoginRepository(api);
      final cancellation = RequestCancellationToken();

      final response = await repository.login(
        const LoginRequest(account: 'user@example.com', password: 'secret'),
        cancelToken: cancellation,
      );

      expect(api.receivedPath, '/auth/login');
      expect(api.receivedData, {
        'account': 'user@example.com',
        'password': 'secret',
      });
      expect(api.receivedCancellation, same(cancellation));
      expect(response.token, 'remote-token');
      expect(response.user.id, 'remote-user');
    },
  );

  test(
    'remote repository rejects a successful response without data',
    () async {
      final api = _FakeApiService()..returnEmptyData = true;
      final repository = RemoteLoginRepository(api);

      await expectLater(
        repository.login(
          const LoginRequest(account: 'user@example.com', password: 'secret'),
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
