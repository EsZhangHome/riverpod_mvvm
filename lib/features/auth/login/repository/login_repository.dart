// lib/features/auth/login/repository/login_repository.dart
//
// 作用：声明登录数据仓库契约，并提供只访问真实后端的默认实现。
//
// 登录数据流：
// SignInUseCase -> LoginRepository.login -> ApiService
// -> LoginResponse -> SignInUseCase -> SessionActivator 建立会话。

import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_cancellation.dart';
import 'auth_endpoints.dart';
import '../model/login_request.dart';
import '../model/login_response.dart';

/// 登录数据源契约。应用用例依赖接口，测试可以注入 Fake Repository。
abstract class LoginRepository {
  /// 校验凭据并返回登录结果。
  ///
  /// - [request]：已由登录 ViewModel 完成空值校验的账号密码请求对象；
  /// - [cancelToken]：从页面级请求处理器透传，页面销毁时可中止真实 Dio 请求。
  ///
  /// 成功返回包含 token/user 的 [LoginResponse]；失败抛出统一网络/业务异常，由
  /// AsyncRequestHandler 映射为用户文案。Repository 不返回 ViewState，也不弹提示。
  Future<LoginResponse> login(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  });
}

/// 只调用真实登录接口的默认 Repository。
///
/// 本类不读取 EnvConfig，也不知道 Mock 是否开启。开发期模拟数据由 Starter 自己的
/// StarterMockLoginRepository 实现，并在应用组合层通过 loginRepositoryProvider
/// override 注入。这样真实仓库只有“调用后端并解释结果”一个变化原因。
class RemoteLoginRepository implements LoginRepository {
  /// 创建真实登录仓库。
  ///
  /// [_apiService] 由 Provider 注入，因此单元测试可以替换网络端口，不会发真实请求。
  RemoteLoginRepository(this._apiService);

  /// 网络抽象，只负责发送请求和解析统一响应，不包含页面或认证状态。
  final ApiService _apiService;

  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  }) async {
    // ApiService 统一处理基础地址、状态码、异常映射和 JSON 转换。
    final response = await _apiService.post<LoginResponse>(
      AuthEndpoints.login,
      data: request.toJson(),
      cancelToken: cancelToken,
      fromJson: (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
    );
    // ApiResponse 成功但 data 为空仍属于协议异常，不能伪装成登录成功。
    final data = response.data;
    if (data == null) {
      throw const ApiException(
        code: ApiException.unknownError,
        message: '响应数据为空',
      );
    }
    return data;
  }
}
