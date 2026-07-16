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
enum AuthStatus {
  /// App 启动后正在从安全存储读取会话；此时路由应等待，不能误跳登录页。
  restoring,

  /// 已确认本地没有有效会话，受保护路由应重定向到登录页。
  unauthenticated,

  /// 已存在完整会话，受保护路由可以进入。
  authenticated,
}

/// 全局认证状态（不可变）。
class AuthState {
  /// 创建“正在恢复会话”状态；session 固定为 null。
  const AuthState.restoring() : status = AuthStatus.restoring, session = null;

  /// 创建“未登录”状态；session 固定为 null。
  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      session = null;

  /// 创建“已登录”状态。
  ///
  /// [session] 必须包含同一次登录产生的非空 token 与用户信息。使用命名构造函数把
  /// status/session 的合法组合固定下来，调用方无法构造“authenticated 但无会话”。
  const AuthState.authenticated(AuthSession this.session)
    : status = AuthStatus.authenticated;

  /// 当前状态机阶段，路由守卫以它作为唯一判断来源。
  final AuthStatus status;

  /// 完整会话；只有 [AuthStatus.authenticated] 时非空。
  final AuthSession? session;

  /// 便捷读取 token。未登录或恢复中返回 null。
  String? get token => session?.token;

  /// 便捷读取当前用户。未登录或恢复中返回 null。
  UserModel? get currentUser => session?.user;

  /// 是否仍在启动恢复阶段。
  bool get isRestoringSession => status == AuthStatus.restoring;

  /// 是否处于内部一致的已登录状态；同时检查枚举和 session，避免异常数据漏过。
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
  /// 创建初始恢复状态，并把安全存储读取安排到当前同步构建结束后的微任务。
  ///
  /// `build` 不能标记 async，因为 AuthState 本身已经显式表示 restoring；如果改用
  /// AsyncNotifier，会同时出现 AsyncLoading 与 AuthStatus.restoring 两套加载语义。
  @override
  AuthState build() {
    Future.microtask(_restoreSession);
    return const AuthState.restoring();
  }

  /// 刷新并原子保存新会话，供 App 组合层的网络绑定调用。
  ///
  /// ViewModel 只依赖 SessionRefresher 和 SessionStore 两个认证领域端口，不知道
  /// Dio、拦截器或请求重放细节。保存失败时返回 null，网络层会按刷新失败处理。
  ///
  /// 返回值：新 token 表示刷新且持久化均成功；null 可能表示当前未登录、刷新服务
  /// 拒绝恢复、Provider 已销毁或安全存储失败。网络层不需要区分这些内部原因，都会
  /// 终止当前请求的自动重放并进入统一会话失效策略。
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

  /// 保存登录成功得到的完整会话。
  ///
  /// - [token]：LoginRepository 返回的 access token；
  /// - [user]：同一响应返回的用户模型。
  ///
  /// 只有安全存储写入成功且 Provider 仍存活时才更新 state，并返回 true。false 表示
  /// 会话没有可靠保存，调用方应留在登录页并展示错误，不能先跳首页再补写凭据。
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
  ///
  /// 本方法没有 BuildContext，也不显式导航。state 改成 unauthenticated 后，AppRouter
  /// 的 refreshListenable 会重新执行 AuthRouteGuard，当前受保护页面自然回到登录页。
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
///
/// `select` 只订阅 `currentUser?.id` 这一小段状态：刷新 token 时 AuthState 虽然变化，
/// 但 id 不变，依赖此 Provider 的用户级业务不会无意义重建。退出/切换用户时 id
/// 变化，相关 Provider 才应该清空或重新加载数据。
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider.select((state) => state.currentUser?.id));
});
