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

/// 登录页面需要的不可变状态。
///
/// 表单文本仍由 TextEditingController 管理；这里仅保存跨异步请求发生变化、
/// 且会影响页面绘制的数据。这样每类状态只有一个明确的所有者。
class LoginState {
  /// 创建登录页状态快照。
  ///
  /// 参数说明：
  /// - [viewState]：当前请求阶段，默认 idle；
  /// - [errorMessage]：可直接展示的本地化文案，非错误对象；
  /// - [token]/[user]：只在登录接口成功后同时存在，供 View 交给 AuthNotifier。
  ///
  /// 文本框内容不在这里保存，因为输入光标、选区和输入法组合态属于 Widget UI 状态。
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

  /// 登录接口是否已经返回非空 token。
  ///
  /// 它不代表全局会话已经持久化；最终登录状态仍以 authProvider 为准。
  bool get isLogin => token != null && token!.isNotEmpty;

  /// 在不可变旧状态基础上创建新状态。
  ///
  /// 普通可空参数传 null 表示沿用旧值；[clearToken]/[clearUser] 专门表达“主动清空”。
  /// 两个 clear 参数优先级更高，例如同时传 `token: 'x', clearToken: true` 最终仍为空。
  /// 之所以需要显式 clear，是因为 `token: null` 无法区分“未传参数”和“想设为 null”。
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

/// 登录页面的 ViewModel。
///
/// Notifier 不持有 BuildContext，也不做路由跳转。它负责校验输入、调用 Repository、
/// 把结果转成 LoginState；View 在成功后把会话交给全局 AuthNotifier。
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
  ///
  /// - [account]：页面输入的账号；发送前会去除首尾空白；
  /// - [password]：页面输入的原始密码，不 trim，避免改变用户真实密码。
  ///
  /// 返回 true 只表示接口已经成功并把 token/user 写入 LoginState；安全持久化由 View
  /// 随后调用 AuthNotifier 完成。重复点击会由按钮禁用和 AsyncRequestHandler 双重拦截。
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

  /// 登录接口已经成功，但会话无法安全保存时回到错误状态。
  ///
  /// 清空临时 token/user 可以防止用户再次操作时误用上一次未持久化成功的结果。
  void showSessionStorageError() {
    state = state.copyWith(
      viewState: ViewState.error,
      errorMessage: AppStrings.storageError,
      clearToken: true,
      clearUser: true,
    );
  }
}

// ==================== Provider ====================

/// 登录页状态 Provider。
///
/// `autoDispose` 表示最后一个监听者离开后销毁 LoginNotifier。build 中注册的
/// `ref.onDispose` 会继续释放 Handler，从而取消页面已不再需要的网络请求。
final loginProvider = NotifierProvider.autoDispose<LoginNotifier, LoginState>(
  LoginNotifier.new,
);
