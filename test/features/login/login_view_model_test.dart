// test/features/login/login_view_model_test.dart
//
// 迁移说明：get_it locator → Riverpod ProviderContainer overrides

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/providers/repositories.dart';
import 'package:riverpod_mvvm/features/login/model/login_request.dart';
import 'package:riverpod_mvvm/features/login/model/login_response.dart';
import 'package:riverpod_mvvm/features/login/repository/login_repository.dart';
import 'package:riverpod_mvvm/features/login/view_model/login_view_model.dart';
import 'package:riverpod_mvvm/shared/models/user_model.dart';

class FakeLoginRepository implements LoginRepository {
  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    CancelToken? cancelToken,
  }) async {
    return const LoginResponse(
      token: 'fake_token',
      user: UserModel(id: '1', name: 'Test User', email: 'test@example.com'),
    );
  }
}

void main() {
  test('login notifier uses fake repository via ProviderContainer override',
      () async {
    final container = ProviderContainer(
      overrides: [
        loginRepositoryProvider.overrideWith((ref) => FakeLoginRepository()),
      ],
    );

    final notifier = container.read(loginProvider.notifier);
    final success = await notifier.login('test@example.com', '123456');

    expect(success, isTrue);
    expect(notifier.state.token, 'fake_token');
    expect(notifier.state.user?.name, 'Test User');
  });
}
