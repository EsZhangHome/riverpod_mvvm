// SignInUseCase 单元测试。
//
// 这里不创建 Widget 或 Riverpod Container，只验证应用用例是否按顺序协调登录数据
// 仓库与会话端口。这样 Repository 协议、会话状态或页面状态任一变化时，失败测试能
// 明确指出是哪一层的责任。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import 'package:riverpod_mvvm/features/auth/login/application/sign_in_use_case.dart';
import 'package:riverpod_mvvm/features/auth/login/model/login_request.dart';
import 'package:riverpod_mvvm/features/auth/login/model/login_response.dart';
import 'package:riverpod_mvvm/features/auth/login/repository/login_repository.dart';
import 'package:riverpod_mvvm/features/auth/session/application/session_activator.dart';
import 'package:riverpod_mvvm/features/auth/session/model/auth_session.dart';
import 'package:riverpod_mvvm/features/auth/session/model/user_model.dart';

const _response = LoginResponse(
  token: 'token',
  user: UserModel(id: '1', name: 'User', email: 'user@example.com'),
);

final class _FakeLoginRepository implements LoginRepository {
  Object? error;
  LoginRequest? receivedRequest;
  RequestCancellationToken? receivedCancelToken;

  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  }) async {
    receivedRequest = request;
    receivedCancelToken = cancelToken;
    if (error case final error?) throw error;
    return _response;
  }
}

final class _FakeSessionActivator implements SessionActivator {
  bool shouldSucceed = true;
  AuthSession? receivedSession;
  var callCount = 0;

  @override
  Future<bool> activateSession(AuthSession session) async {
    callCount++;
    receivedSession = session;
    return shouldSucceed;
  }
}

void main() {
  test(
    'successful repository result is activated as one complete session',
    () async {
      final repository = _FakeLoginRepository();
      final activator = _FakeSessionActivator();
      final useCase = SignInUseCase(
        loginRepository: repository,
        sessionActivator: activator,
      );
      final token = RequestCancellationToken();
      const request = LoginRequest(account: 'user', password: 'password');

      final result = await useCase(request, cancelToken: token);

      expect(result, SignInResult.authenticated);
      expect(repository.receivedRequest, request);
      expect(repository.receivedCancelToken, same(token));
      expect(activator.callCount, 1);
      expect(activator.receivedSession?.token, _response.token);
      expect(activator.receivedSession?.user, _response.user);
    },
  );

  test('session activation failure remains a typed use-case result', () async {
    final repository = _FakeLoginRepository();
    final activator = _FakeSessionActivator()..shouldSucceed = false;
    final useCase = SignInUseCase(
      loginRepository: repository,
      sessionActivator: activator,
    );

    final result = await useCase(
      const LoginRequest(account: 'user', password: 'password'),
    );

    expect(result, SignInResult.sessionActivationFailed);
    expect(activator.callCount, 1);
  });

  test(
    'repository failure is propagated and session is not activated',
    () async {
      final repository = _FakeLoginRepository()
        ..error = StateError('login failed');
      final activator = _FakeSessionActivator();
      final useCase = SignInUseCase(
        loginRepository: repository,
        sessionActivator: activator,
      );

      await expectLater(
        useCase(const LoginRequest(account: 'user', password: 'password')),
        throwsStateError,
      );
      expect(activator.callCount, 0);
    },
  );
}
