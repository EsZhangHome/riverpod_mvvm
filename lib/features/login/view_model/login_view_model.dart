// lib/features/login/view_model/login_view_model.dart
//
// 作用：登录页 Notifier，负责登录表单校验和登录业务逻辑。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/base/base_view_model.dart';
import '../../../core/base/view_state.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/repositories.dart';
import '../../../shared/models/user_model.dart';
import '../model/login_request.dart';

// ==================== 状态类 ====================

class LoginState {
  const LoginState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    this.token,
    this.user,
  });

  final ViewState viewState;
  final String errorMessage;
  final String? token;
  final UserModel? user;

  bool get isLogin => token != null && token!.isNotEmpty;

  LoginState copyWith({
    ViewState? viewState,
    String? errorMessage,
    String? token,
    UserModel? user,
    bool clearToken = false,
    bool clearUser = false,
  }) {
    return LoginState(
      viewState: viewState ?? this.viewState,
      errorMessage: errorMessage ?? this.errorMessage,
      token: clearToken ? null : token ?? this.token,
      user: clearUser ? null : user ?? this.user,
    );
  }
}

// ==================== Notifier ====================

class LoginNotifier extends Notifier<LoginState> {
  late final _handler = AsyncRequestHandler();

  @override
  LoginState build() {
    ref.onDispose(() => _handler.dispose());
    return const LoginState();
  }

  /// 执行登录操作。返回 true 表示登录成功。
  Future<bool> login(String account, String password) async {
    if (account.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        viewState: ViewState.error,
        errorMessage: AppStrings.enterAccountAndPassword,
      );
      return false;
    }

    final response = await _handler.execute(
      request: () => ref
          .read(loginRepositoryProvider)
          .login(
            LoginRequest(account: account.trim(), password: password.trim()),
            cancelToken: _handler.cancelToken,
          ),
      onLoading: () => state = state.copyWith(viewState: ViewState.loading),
      onSuccess: () => state = state.copyWith(viewState: ViewState.success),
      onError: (msg) =>
          state = state.copyWith(viewState: ViewState.error, errorMessage: msg),
    );

    if (!ref.mounted || response == null) return false;

    state = state.copyWith(token: response.token, user: response.user);
    return true;
  }
}

// ==================== Provider ====================

final loginProvider = NotifierProvider.autoDispose<LoginNotifier, LoginState>(
  LoginNotifier.new,
);
