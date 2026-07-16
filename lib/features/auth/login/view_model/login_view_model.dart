// lib/features/auth/login/view_model/login_view_model.dart
//
// 作用：登录页 Notifier，负责登录表单校验和登录业务逻辑。
//
// 阅读顺序：
// 1. LoginState 保存 View 真正需要的加载、错误和成功结果；
// 2. LoginNotifier 校验输入并调用 SignIn 应用用例；
// 3. AsyncRequestHandler 管理重复请求、网络库无关的取消令牌和错误映射；
// 4. SignInUseCase 在 ViewModel 外协调 Repository 与全局会话端口。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/state/async_request_handler.dart';
import '../../../../shared/state/view_state.dart';
import '../../../../shared/localization/user_message.dart';
import '../application/sign_in_use_case.dart';
import '../../auth_composition.dart';
import '../model/login_request.dart';

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
  /// - [feedbackMessage]：等待 View 按当前 Locale 解析的安全消息；
  /// - [feedbackId]：每发布一次轻提示就递增，帮助 View 识别一次性事件；
  ///
  /// 文本框内容不在这里保存，因为输入光标、选区和输入法组合态属于 Widget UI 状态。
  const LoginState({
    this.viewState = ViewState.idle,
    this.feedbackMessage,
    this.feedbackId = 0,
  });

  /// 控制页面 idle/loading/success/error 的展示状态。
  final ViewState viewState;

  /// 最近一次可展示的类型化消息，不把 DioException 或固定中文暴露给 View。
  ///
  /// 登录属于表单提交：校验失败或请求失败后，用户仍需继续修改输入。因此这里的错误
  /// 由 LoginPage 监听并显示成 Toast，而不是让 StateView 用 ErrorView 替换整个表单。
  final UserMessage? feedbackMessage;

  /// 一次性提示的递增编号。
  ///
  /// 不能只监听 [feedbackMessage]：用户连续两次提交空表单时，两次消息键完全相同，Riverpod
  /// 的 `select` 会认为值没有变化，第二次就不会提示。每次错误同时递增 feedbackId，
  /// View 就能准确消费每一次操作结果。0 表示页面创建后还没有发布过提示。
  final int feedbackId;

  /// 在不可变旧状态基础上创建新状态。
  ///
  /// [clearFeedbackMessage] 用来明确清除旧消息。不能只传 null，因为 null 还要表达
  /// “本次不修改该字段”。登录成功结果不保存在页面 State 中，避免 View 参与会话编排。
  LoginState copyWith({
    ViewState? viewState,
    UserMessage? feedbackMessage,
    bool clearFeedbackMessage = false,
    int? feedbackId,
  }) {
    // 每次创建新对象，Riverpod 才能可靠识别状态变化；不原地修改旧 State。
    return LoginState(
      viewState: viewState ?? this.viewState,
      feedbackMessage: clearFeedbackMessage
          ? null
          : feedbackMessage ?? this.feedbackMessage,
      feedbackId: feedbackId ?? this.feedbackId,
    );
  }
}

// ==================== Notifier ====================

/// 登录页面的 ViewModel。
///
/// Notifier 不持有 BuildContext，也不做路由跳转。它负责校验输入、调用 Repository、
/// 把最终结果转成 LoginState。真正的“Repository 登录 → 建立全局会话”顺序由
/// SignInUseCase 管理；ViewModel 不依赖 AuthNotifier、SessionStore 或 ApiService。
class LoginNotifier extends Notifier<LoginState> {
  // Handler 与当前 Provider 实例同生命周期，集中持有底座自己的取消令牌。
  late final _handler = AsyncRequestHandler();

  @override
  LoginState build() {
    // autoDispose Provider 销毁时释放 Handler，并取消仍在执行的登录请求。
    ref.onDispose(() => _handler.dispose());
    return const LoginState();
  }

  /// 执行一条完整登录用例：校验 → 请求 → 持久化 → 发布全局认证态。
  ///
  /// - [account]：页面输入的账号；发送前会去除首尾空白；
  /// - [password]：页面输入的原始密码，不 trim，避免改变用户真实密码。
  ///
  /// View 不需要读取返回值或接口模型。成功后 authProvider 的状态变化会让统一路由守卫
  /// 自动离开登录页；失败时当前 Provider 发布一次类型化 Toast 消息。重复点击会由
  /// 按钮禁用和 AsyncRequestHandler 双重拦截。
  Future<void> login(String account, String password) async {
    // 步骤 1：同步校验在发请求前完成，减少无意义的 Repository 调用。
    // 分开判断可以让 Toast 准确告诉用户当前缺少哪一项；两项都为空时先提示账号，
    // 用户补充账号再次提交后，再提示密码，符合表单从上到下的填写顺序。
    if (account.trim().isEmpty) {
      _publishError(const UserMessage.localized(UserMessageKey.enterAccount));
      return;
    }
    if (password.isEmpty) {
      _publishError(const UserMessage.localized(UserMessageKey.enterPassword));
      return;
    }

    // 步骤 2：ViewModel 只创建经过表单规则处理的命令参数，然后调用 SignIn 抽象。
    // 账号首尾空白通常是误输入，可以安全去除；密码可能合法包含空格，必须原样发送。
    final result = await _handler.execute<SignInResult>(
      request: () => ref.read(signInProvider)(
        LoginRequest(account: account.trim(), password: password),
        cancelToken: _handler.cancelToken,
      ),
      onLoading: () => state = state.copyWith(
        viewState: ViewState.loading,
        // 清空旧消息不会重复显示，因为 feedbackId 没有变化。
        clearFeedbackMessage: true,
      ),
      // 用例返回 authenticated 之前已经完成会话持久化；但最终页面状态需要根据
      // 具体 SignInResult 判断，所以不在 Handler 的通用同步回调中提前写 success。
      onSuccess: () {},
      onError: _publishError,
    );

    // 步骤 3：await 期间页面可能已经销毁；此时禁止回写失效 Provider。
    if (!ref.mounted || result == null) return;

    // 步骤 4：ViewModel 只解释用例结果，不知道失败来自哪种安全存储实现。
    if (result == SignInResult.sessionActivationFailed) {
      _publishError(const UserMessage.localized(UserMessageKey.storageError));
      return;
    }

    // 用例成功时全局认证态已经建立。这里只完成页面局部状态，导航仍统一由
    // AuthRouteGuard 响应 AuthState，不在 ViewModel 中写死任何项目首页路径。
    state = state.copyWith(
      viewState: ViewState.success,
      clearFeedbackMessage: true,
    );
  }

  /// 发布一次可由 View 显示为 Toast 的错误提示。
  ///
  /// [message] 已由表单校验或 FailureMessageResolver 转换成安全类型；固定消息还没有
  /// 被翻译，View 会根据当前 Locale 解析，因此 ViewModel 不会锁死中文。
  ///
  /// 错误后回到 idle 而不是 error：`ViewState.error` 在通用 StateView 中代表“整页加载
  /// 失败”，会用 ErrorView 替换内容；登录错误是可恢复的表单操作结果，应该保留表单，
  /// 让用户看到 Toast 后立即修改并重试。
  void _publishError(UserMessage message) {
    state = state.copyWith(
      viewState: ViewState.idle,
      feedbackMessage: message,
      feedbackId: state.feedbackId + 1,
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
