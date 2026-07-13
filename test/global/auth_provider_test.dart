// AuthNotifier 会话测试。
//
// FlutterSecureStorage 和 SharedPreferences 都使用内存 Mock，验证恢复、保存和清理
// 的完整数据流，不访问设备 Keychain/Keystore。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/storage/local_storage.dart';
import 'package:riverpod_mvvm/core/storage/token_storage.dart';
import 'package:riverpod_mvvm/global/auth_provider.dart';
import 'package:riverpod_mvvm/shared/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AuthState> _waitForRestoration(ProviderContainer container) async {
  // build() 用 microtask 启动安全存储读取；轮询只用于测试同步点，最多等待 1 秒。
  for (var attempt = 0; attempt < 100; attempt++) {
    final state = container.read(authProvider);
    if (!state.isRestoringSession) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('AuthNotifier did not finish session restoration');
}

void main() {
  test('restores token and user from local stores', () async {
    SharedPreferences.setMockInitialValues({
      'current_user':
          '{"id":"1","name":"Saved User","email":"saved@example.com"}',
    });
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'saved_token'});
    await LocalStorage.init();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await _waitForRestoration(container);

    expect(state.isLoggedIn, isTrue);
    expect(state.token, 'saved_token');
    expect(state.currentUser?.name, 'Saved User');
  });

  test('loginSuccess persists session and logout clears it', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await LocalStorage.init();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _waitForRestoration(container);
    const user = UserModel(id: '2', name: 'New User', email: 'new@example.com');

    await container.read(authProvider.notifier).loginSuccess('new_token', user);

    expect(container.read(authProvider).currentUser, user);
    expect(await TokenStorage.getToken(), 'new_token');
    expect(LocalStorage.getString('current_user'), contains('New User'));

    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider).isLoggedIn, isFalse);
    expect(await TokenStorage.getToken(), isNull);
    expect(LocalStorage.getString('current_user'), isNull);
  });
}
