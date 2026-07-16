// lib/features/auth/repository/login_repository.dart
//
// 作用：登录数据仓库，负责执行登录请求并返回登录结果。
//
// Mock 开关：通过 EnvConfig.enableMock 控制，`flutter run --dart-define=ENV_ENABLE_MOCK=false` 切换到真实接口。
//
// 登录数据流：
// SignInUseCase -> LoginRepository.login -> Mock 或 ApiService
// -> LoginResponse -> SignInUseCase -> SessionActivator 建立会话。

import '../../../core/config/env_config.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/request_cancellation.dart';
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

/// 根据编译环境在 Mock 与真实接口之间切换的 Repository 实现。
class LoginRepositoryImpl implements LoginRepository {
  /// 创建真实/Mock 可切换的登录仓库。
  ///
  /// [_apiService] 由 Provider 注入。即使当前编译环境开启 Mock 也仍注入该依赖，
  /// 这样关闭 Mock 后无需改对象结构，单元测试也能稳定替换网络端口。
  LoginRepositoryImpl(this._apiService);

  /// 网络抽象，只负责发送请求和解析统一响应，不包含页面或认证状态。
  final ApiService _apiService;

  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  }) async {
    // 步骤 1：开发环境走可重复运行的本地 Mock，不依赖后端。
    if (EnvConfig.enableMock) {
      return _mockLogin(request);
    }
    // 步骤 2：关闭 Mock 后走真实接口，并继续传递取消令牌。
    return _apiLogin(request, cancelToken: cancelToken);
  }

  Future<LoginResponse> _mockLogin(LoginRequest request) async {
    // 模拟网络耗时，让页面仍能演示 overlay loading。
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // 仍通过 fromJson 构造，确保 Mock 与真实接口复用同一解析路径。
    return LoginResponse.fromJson({
      'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      'user': {
        'id': '1',
        'name': request.account.contains('@') ? 'Flutter User' : 'Mobile User',
        'email': request.account.contains('@')
            ? request.account
            : 'user@example.com',
        'avatarUrl': null,
      },
    });
  }

  Future<LoginResponse> _apiLogin(
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
