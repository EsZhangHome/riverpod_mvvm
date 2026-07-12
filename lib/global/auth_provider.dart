// lib/global/auth_provider.dart
//
// 作用：全局登录状态管理器，统一管理 token、当前用户、登录/退出/恢复会话。
//
// 迁移说明（Provider → Riverpod）：
// - 旧的 AuthProvider extends ChangeNotifier → 新的 AuthNotifier extends Notifier<AuthState>
// - notifyListeners() → state = newState（Riverpod 自动通知监听者）
// - context.watch/read<AuthProvider> → ref.watch/read(authProvider)
// - GoRouter 的 refreshListenable → 在 _AppView 中 ref.listen 触发路由刷新
//
// 数据流保持不变：
// 登录：LoginPage → authNotifier.loginSuccess(token, user) → state 更新
// 退出：MinePage → authNotifier.logout() → state 更新
// 恢复：build() 中自动调用 restoreSession()
// 401：ApiClient 回调 → authNotifier.logout()

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/services.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/token_storage.dart';
import '../shared/models/user_model.dart';

// ==================== 状态类 ====================

/// 全局登录状态（不可变）。
class AuthState {
  const AuthState({
    this.token,
    this.currentUser,
    this.isRestoringSession = false,
  });

  /// 当前 token，null 表示未登录
  final String? token;

  /// 当前登录用户信息
  final UserModel? currentUser;

  /// 是否正在从本地存储恢复登录态
  final bool isRestoringSession;

  /// 是否已登录
  bool get isLoggedIn => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? token,
    UserModel? currentUser,
    bool? isRestoringSession,
    bool clearToken = false,
    bool clearUser = false,
  }) {
    return AuthState(
      token: clearToken ? null : token ?? this.token,
      currentUser: clearUser ? null : currentUser ?? this.currentUser,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
    );
  }
}

// ==================== Notifier ====================

/// 全局登录状态 Notifier。
///
/// 作为 NotifierProvider 在 App 顶层通过 ProviderScope 提供。
/// 所有页面通过 ref.watch(authProvider) 监听登录状态变化。
class AuthNotifier extends Notifier<AuthState> {
  // ==================== 常量 ====================

  static const String _userKey = 'current_user';

  // ==================== 构建 ====================

  @override
  AuthState build() {
    final apiClient = ref.read(apiClientProvider);
    // 注入网络层回调：tokenProvider 和 unauthorisedCallback
    // 闭包捕获 this，每次调用时返回最新的 state.token
    apiClient.setTokenProvider(() => state.token);
    apiClient.setUnauthorizedCallback(logout);

    // 启动时从本地恢复登录态
    // 使用 Future.microtask 延迟执行：build() 期间 state 尚未完全初始化
    // 初始状态设为 isRestoringSession = true，路由守卫会在此期间停留在启动页
    Future.microtask(_restoreSession);
    return const AuthState(isRestoringSession: true);
  }

  // ==================== 会话恢复 ====================

  Future<void> _restoreSession() async {
    if (state.isLoggedIn) return;

    state = state.copyWith(isRestoringSession: true);

    try {
      final token = await TokenStorage.getToken();
      final userJson = LocalStorage.getString(_userKey);
      UserModel? user;
      if (userJson != null && userJson.isNotEmpty) {
        user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      }
      state = state.copyWith(
        token: token,
        currentUser: user,
        isRestoringSession: false,
      );
    } catch (_) {
      state = state.copyWith(isRestoringSession: false);
    }
  }

  // ==================== 登录 ====================

  /// 登录成功后保存 token 和用户信息。
  ///
  /// 调用时机：LoginPage 在登录成功后调用。
  Future<void> loginSuccess(String token, UserModel user) async {
    // 更新内存状态
    state = state.copyWith(token: token, currentUser: user);

    // 重置 401 守卫，允许新会话的下一次 401 触发退出
    ref.read(apiClientProvider).resetUnauthorizedGuard();

    // 写入本地存储
    await TokenStorage.saveToken(token);
    await LocalStorage.setString(_userKey, jsonEncode(user.toJson()));
  }

  // ==================== 退出登录 ====================

  /// 退出登录，清空内存和本地缓存。
  ///
  /// 调用时机：MinePage、ProfilePage 的退出按钮，以及 401 回调。
  Future<void> logout() async {
    // 清空内存状态
    state = state.copyWith(clearToken: true, clearUser: true);

    // 清除本地存储
    await TokenStorage.clearToken();
    await LocalStorage.remove(_userKey);
  }
}

// ==================== Provider ====================

/// 全局登录状态 Provider。
///
/// 使用方式：
/// ```dart
/// // 监听登录状态
/// final authState = ref.watch(authProvider);
///
/// // 执行登录/退出操作
/// ref.read(authProvider.notifier).loginSuccess(token, user);
/// ref.read(authProvider.notifier).logout();
/// ```
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
