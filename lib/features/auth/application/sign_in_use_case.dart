// 登录应用用例。
//
// 它只负责一个完整业务动作：校验凭据的远端结果成功后，建立对应的全局会话。
// 页面 loading、Toast 和输入框属于 LoginNotifier；HTTP 与 JSON 属于 LoginRepository；
// 安全存储与认证 State 属于 SessionActivator。这里负责按正确顺序协调三者。

import '../../../core/network/request_cancellation.dart';
import '../model/auth_session.dart';
import '../model/login_request.dart';
import '../repository/login_repository.dart';
import 'session_activator.dart';

/// 一次登录应用用例的稳定结果。
enum SignInResult {
  /// 登录接口成功、会话已安全保存并发布。
  authenticated,

  /// 登录接口成功，但会话无法可靠保存，因此不能进入已登录页面。
  sessionActivationFailed,
}

/// LoginNotifier 依赖的登录用例抽象。
///
/// 测试可以替换本接口，只验证表单 ViewModel；真实组合使用下面的 [SignInUseCase]。
abstract interface class SignIn {
  Future<SignInResult> call(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  });
}

/// [SignIn] 的默认实现，负责登录 Repository 与会话端口之间的业务编排。
final class SignInUseCase implements SignIn {
  const SignInUseCase({
    required this.loginRepository,
    required this.sessionActivator,
  });

  /// 只负责校验账号凭据并返回强类型登录结果的数据仓库。
  final LoginRepository loginRepository;

  /// 只负责原子保存并发布全局会话的抽象端口。
  final SessionActivator sessionActivator;

  @override
  Future<SignInResult> call(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  }) async {
    // 第一步只处理远端身份校验。异常保持原样抛出，交给 ViewModel 的统一请求处理器
    // 转换为类型化用户消息；用例不负责 Toast 或 ViewState。
    final response = await loginRepository.login(
      request,
      cancelToken: cancelToken,
    );

    // token 与用户必须作为一个 AuthSession 交给会话端口，不能分别写入存储，否则
    // 任一写入失败都可能形成“有 token、无用户”的半登录状态。
    final activated = await sessionActivator.activateSession(
      AuthSession(token: response.token, user: response.user),
    );
    return activated
        ? SignInResult.authenticated
        : SignInResult.sessionActivationFailed;
  }
}
