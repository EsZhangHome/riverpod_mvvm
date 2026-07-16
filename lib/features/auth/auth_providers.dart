// lib/features/auth/auth_providers.dart
//
// Auth 模块的 Repository 依赖组装入口。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../core/storage/local_storage.dart';
import 'repository/login_repository.dart';
import 'repository/session_refresher.dart';
import 'repository/session_store.dart';

/// 登录 Repository。ViewModel 依赖抽象接口，不直接接触 ApiService。
final loginRepositoryProvider = Provider<LoginRepository>((ref) {
  return LoginRepositoryImpl(ref.watch(apiServiceProvider));
});

/// Token 刷新能力的注入点。
///
/// 默认实现返回 null，因为底座不知道后端使用 refresh_token、SSO Cookie 还是
/// OAuth。正式项目只需 override 此 Provider，无需修改 ApiClient 或 AuthNotifier。
final sessionRefresherProvider = Provider<SessionRefresher>(
  (ref) => const DisabledSessionRefresher(),
);

/// 完整认证会话存储。测试可 override 为内存实现，不接触平台 Keychain/Keystore。
final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SecureSessionStore(
    ref.watch(secureStorageServiceProvider),
    readLegacyUserJson: () => LocalStorage.getString('current_user'),
    clearLegacyUser: () async {
      await LocalStorage.remove('current_user');
    },
  );
});
