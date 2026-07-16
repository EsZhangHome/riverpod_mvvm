// lib/features/auth/view_model/auth_view_model.dart
//
// App 级认证 ViewModel。它管理“恢复中、未登录、已登录”三种稳定状态，负责把
// 完整 AuthSession 交给 SessionStore，不直接操作 Keychain 或 SharedPreferences。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/crash_reporter.dart';
import '../auth_providers.dart';
import '../model/auth_session.dart';
import '../model/user_model.dart';

/// 认证状态机。显式枚举比多个 bool 更难组合出矛盾状态。
enum AuthStatus { restoring, unauthenticated, authenticated }

/// 全局认证状态（不可变）。
class AuthState {
  const AuthState.restoring() : status = AuthStatus.restoring, session = null;

  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      session = null;

  const AuthState.authenticated(AuthSession this.session)
    : status = AuthStatus.authenticated;

  final AuthStatus status;
  final AuthSession? session;

  String? get token => session?.token;
  UserModel? get currentUser => session?.user;
  bool get isRestoringSession => status == AuthStatus.restoring;
  bool get isLoggedIn => status == AuthStatus.authenticated && session != null;
}

/// App 级认证 ViewModel。
///
/// 状态更新规则：
/// - 恢复：安全存储完整解析成功才进入 authenticated；
/// - 登录：完整会话写入成功才更新内存状态；
/// - 刷新：新 token 持久化成功后才让请求重放；
/// - 退出：立即清内存，再尽力清安全存储并上报失败。
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restoreSession);
    return const AuthState.restoring();
  }

  /// 刷新并原子保存新会话，供 App 组合层的网络绑定调用。
  ///
  /// ViewModel 只依赖 SessionRefresher 和 SessionStore 两个认证领域端口，不知道
  /// Dio、拦截器或请求重放细节。保存失败时返回 null，网络层会按刷新失败处理。
  Future<String?> refreshAccessToken() async {
    final current = state.session;
    if (current == null) return null;
    final token = await ref.read(sessionRefresherProvider).refreshAccessToken();
    if (token == null || token.isEmpty || !ref.mounted) return null;

    final refreshed = AuthSession(token: token, user: current.user);
    try {
      await ref.read(sessionStoreProvider).write(refreshed);
    } catch (error, stack) {
      CrashReporter.report(error, stack);
      return null;
    }
    if (!ref.mounted) return null;
    state = AuthState.authenticated(refreshed);
    return token;
  }

  Future<void> _restoreSession() async {
    final store = ref.read(sessionStoreProvider);
    try {
      final session = await store.read();
      if (!ref.mounted) return;
      if (session == null) {
        state = const AuthState.unauthenticated();
        return;
      }
      state = AuthState.authenticated(session);
      CrashReporter.setContext('userId', session.user.id);
    } catch (error, stack) {
      // 损坏或旧版本会话不能继续使用。先尝试清除，避免每次启动重复解析失败。
      CrashReporter.report(error, stack);
      try {
        await store.clear();
      } catch (clearError, clearStack) {
        CrashReporter.report(clearError, clearStack);
      }
      if (ref.mounted) state = const AuthState.unauthenticated();
    }
  }

  /// 保存完整会话。返回 false 表示安全存储失败，调用方应留在登录页。
  Future<bool> loginSuccess(String token, UserModel user) async {
    final session = AuthSession(token: token, user: user);
    try {
      await ref.read(sessionStoreProvider).write(session);
    } catch (error, stack) {
      CrashReporter.report(error, stack);
      return false;
    }
    if (!ref.mounted) return false;

    state = AuthState.authenticated(session);
    CrashReporter.setContext('userId', user.id);
    return true;
  }

  /// 清理登录态。内存立即退出，安全存储失败会记录并重试一次。
  Future<void> logout() async {
    state = const AuthState.unauthenticated();
    CrashReporter.setContext('userId', null);
    final store = ref.read(sessionStoreProvider);
    try {
      await store.clear();
    } catch (error, stack) {
      CrashReporter.report(error, stack);
      try {
        await store.clear();
      } catch (retryError, retryStack) {
        CrashReporter.report(retryError, retryStack);
      }
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// 用户级缓存只依赖用户 id；刷新 token 不会让购物车、收藏等状态重建。
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider.select((state) => state.currentUser?.id));
});
