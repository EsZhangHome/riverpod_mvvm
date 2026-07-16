// lib/features/auth/view_model/login_view_model.dart
//
// 作用：登录页 Notifier，负责登录表单校验和登录业务逻辑。
//
// 阅读顺序：
// 1. LoginState 保存 View 真正需要的加载、错误和成功结果；
// 2. LoginNotifier 校验输入并通过 Repository 发起请求；
// 3. AsyncRequestHandler 管理重复请求、CancelToken 和错误映射；
// 4. LoginPage 收到成功结果后，再交给 App 级 AuthNotifier 保存会话。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/async_request_handler.dart';
import '../../../shared/state/view_state.dart';
import '../../../shared/localization/app_strings.dart';
import '../auth_providers.dart';
import '../model/login_request.dart';
import '../model/user_model.dart';

// ==================== 状态类 ====================

class LoginState {
  const LoginState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    this.token,
    this.user,
  });

  /// 控制页面 idle/loading/success/error 的展示状态。
  final ViewState viewState;

  /// 只存可展示错误文案，不把 DioException 暴露给 View。
  final String errorMessage;

  /// 登录成功结果；登录页面读取后交给全局 AuthNotifier。
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
    // 每次创建新对象，Riverpod 才能可靠识别状态变化；不原地修改旧 State。
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
  // Handler 与当前 Provider 实例同生命周期，集中持有 CancelToken。
  late final _handler = AsyncRequestHandler();

  @override
  LoginState build() {
    // autoDispose Provider 销毁时释放 Handler，并取消仍在执行的登录请求。
    ref.onDispose(() => _handler.dispose());
    return const LoginState();
  }

  /// 执行登录操作。返回 true 表示登录成功。
  Future<bool> login(String account, String password) async {
    // 步骤 1：同步校验在发请求前完成，减少无意义的 Repository 调用。
    if (account.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        viewState: ViewState.error,
        errorMessage: AppStrings.enterAccountAndPassword,
      );
      return false;
    }

    // 步骤 2：Handler 把请求生命周期转换为 ViewState，并统一处理异常。
    final response = await _handler.execute(
      // read 只执行一次命令，不让 Notifier 反向订阅 Repository。
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

    // 步骤 3：await 期间页面可能已经销毁；此时禁止回写失效 Provider。
    if (!ref.mounted || response == null) return false;

    // 步骤 4：保存页面需要读取的成功结果，由 View 决定后续导航和全局会话更新。
    state = state.copyWith(token: response.token, user: response.user);
    return true;
  }
}

// ==================== Provider ====================

// 登录表单离开后无需保留，autoDispose 同时保证未完成请求被取消。
final loginProvider = NotifierProvider.autoDispose<LoginNotifier, LoginState>(
  LoginNotifier.new,
);
