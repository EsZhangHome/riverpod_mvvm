// lib/features/auth/auth_providers.dart
//
// Auth 模块的 Repository 依赖组装入口。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import 'repository/login_repository.dart';
import 'repository/session_refresher.dart';
import 'repository/session_store.dart';

/// 登录 Repository 的依赖注入入口。
///
/// [SignInUseCase] 使用的是 [LoginRepository] 抽象；这里才决定生产实现使用
/// [LoginRepositoryImpl]，并把全局 [ApiService] 注入进去。用例测试可以替换本
/// Provider，ViewModel 测试则直接替换更上层的 signInProvider，保持测试职责单一。
final loginRepositoryProvider = Provider<LoginRepository>((ref) {
  return LoginRepositoryImpl(ref.watch(apiServiceProvider));
});

/// Token 刷新能力的注入点。
///
/// 默认实现返回 null，因为底座不知道后端使用 refresh_token、SSO Cookie 还是
/// OAuth。正式项目只需 override 此 Provider，无需修改 ApiClient 或 AuthNotifier。
///
/// override 的实现应自行持有刷新所需凭据，并避免复用会再次触发 401 刷新的同一
/// 请求链，否则可能形成“刷新接口 401 → 再刷新”的递归。
final sessionRefresherProvider = Provider<SessionRefresher>(
  (ref) => const DisabledSessionRefresher(),
);

/// 完整认证会话存储的注入入口。
///
/// 正式运行使用 [SecureSessionStore]，把 token 与用户作为一个 JSON 整体写入安全
/// 存储，避免出现只写成功一半的会话。两个 legacy 回调只用于兼容底座旧版本：
/// - `readLegacyUserJson` 从旧 SharedPreferences key 读取用户 JSON；
/// - `clearLegacyUser` 在迁移/退出后删除旧数据。
///
/// 全新项目不需要关心这两个回调；测试可 override 为纯内存 SessionStore。
final sessionStoreProvider = Provider<SessionStore>((ref) {
  final preferences = ref.watch(preferencesStoreProvider);
  return SecureSessionStore(
    ref.watch(secureStorageServiceProvider),
    readLegacyUserJson: () => preferences.getString('current_user'),
    clearLegacyUser: () async {
      await preferences.remove('current_user');
    },
  );
});
