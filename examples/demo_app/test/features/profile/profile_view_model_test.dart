// ProfileNotifier 测试：验证 ViewModel 只编排状态和 Repository，不依赖页面。

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/shared/state/view_state.dart';
import 'package:riverpod_mvvm_demo/features/profile/profile_providers.dart';
import 'package:riverpod_mvvm_demo/features/profile/repository/profile_repository.dart';
import 'package:riverpod_mvvm_demo/features/profile/view_model/profile_view_model.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

class _FakeProfileRepository implements ProfileRepository {
  int callCount = 0;

  @override
  Future<UserModel> fetchProfile(
    UserModel fallbackUser, {
    CancelToken? cancelToken,
  }) async {
    callCount++;
    return UserModel(
      id: fallbackUser.id,
      name: '${fallbackUser.name} Detail',
      email: fallbackUser.email,
    );
  }
}

void main() {
  test('missing session user fails without repository request', () async {
    final repository = _FakeProfileRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWith((ref) => repository)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(profileProvider.notifier);
    await notifier.loadProfile(null);

    expect(repository.callCount, 0);
    expect(notifier.state.viewState, ViewState.error);
    expect(notifier.state.errorMessage, isNotEmpty);
  });

  test('successful repository result updates profile state', () async {
    final repository = _FakeProfileRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWith((ref) => repository)],
    );
    addTearDown(container.dispose);
    const user = UserModel(id: '1', name: 'User', email: 'u@example.com');

    final notifier = container.read(profileProvider.notifier);
    await notifier.loadProfile(user);

    expect(notifier.state.viewState, ViewState.success);
    expect(notifier.state.user?.name, 'User Detail');
  });
}
