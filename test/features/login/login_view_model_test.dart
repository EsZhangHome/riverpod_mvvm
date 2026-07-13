// test/features/login/login_view_model_test.dart
// LoginNotifier 单元测试。
//
// ProviderContainer 代替 Widget 树创建 Provider；Repository override 隔离网络层，
// 从而只验证输入校验、请求参数和不可变 LoginState。

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/providers/repositories.dart';
import 'package:riverpod_mvvm/core/base/view_state.dart';
import 'package:riverpod_mvvm/core/network/api_exception.dart';
import 'package:riverpod_mvvm/features/login/model/login_request.dart';
import 'package:riverpod_mvvm/features/login/model/login_response.dart';
import 'package:riverpod_mvvm/features/login/repository/login_repository.dart';
import 'package:riverpod_mvvm/features/login/view_model/login_view_model.dart';
import 'package:riverpod_mvvm/shared/models/user_model.dart';

class FakeLoginRepository implements LoginRepository {
  FakeLoginRepository({this.error});

  final Object? error;
  LoginRequest? receivedRequest;
  CancelToken? receivedCancelToken;
  int callCount = 0;

  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    CancelToken? cancelToken,
  }) async {
    callCount++;
    receivedRequest = request;
    receivedCancelToken = cancelToken;
    if (error case final error?) throw error;
    return const LoginResponse(
      token: 'fake_token',
      user: UserModel(id: '1', name: 'Test User', email: 'test@example.com'),
    );
  }
}

void main() {
  test('login notifier uses overridden repository and stores result', () async {
    // Arrange：Container 中只替换 Repository，Notifier 仍走生产创建路径。
    final repository = FakeLoginRepository();
    final container = ProviderContainer(
      overrides: [loginRepositoryProvider.overrideWith((ref) => repository)],
    );
    addTearDown(container.dispose);

    // Act：read(notifier) 用于发送命令，不需要 Widget。
    final notifier = container.read(loginProvider.notifier);
    final success = await notifier.login('test@example.com', '123456');

    // Assert：Repository 收到 trim 后参数和与 Provider 同生命周期的令牌。
    expect(success, isTrue);
    expect(notifier.state.token, 'fake_token');
    expect(notifier.state.user?.name, 'Test User');
    expect(repository.receivedRequest?.account, 'test@example.com');
    expect(repository.receivedCancelToken, isNotNull);
  });

  test('empty input fails before calling repository', () async {
    final repository = FakeLoginRepository();
    final container = ProviderContainer(
      overrides: [loginRepositoryProvider.overrideWith((ref) => repository)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(loginProvider.notifier);
    final success = await notifier.login('  ', '');

    expect(success, isFalse);
    expect(repository.callCount, 0);
    expect(notifier.state.viewState, ViewState.error);
    expect(notifier.state.errorMessage, isNotEmpty);
  });

  test('business error becomes a displayable LoginState error', () async {
    final repository = FakeLoginRepository(
      error: BusinessException(code: 1001, userMessage: '账号已冻结'),
    );
    final container = ProviderContainer(
      overrides: [loginRepositoryProvider.overrideWith((ref) => repository)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(loginProvider.notifier);
    final success = await notifier.login('user', 'password');

    expect(success, isFalse);
    expect(notifier.state.viewState, ViewState.error);
    expect(notifier.state.errorMessage, '账号已冻结');
    expect(notifier.state.token, isNull);
  });
}
