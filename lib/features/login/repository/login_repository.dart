// lib/features/login/repository/login_repository.dart
//
// 作用：登录数据仓库，负责执行登录请求并返回登录结果。
//
// Mock 开关：通过 EnvConfig.enableMock 控制，`flutter run --dart-define=ENV_ENABLE_MOCK=false` 切换到真实接口。
//
// 登录数据流：
// LoginNotifier -> LoginRepository.login -> Mock 或 ApiService
// -> LoginResponse -> LoginNotifier -> AuthNotifier 持久化会话。

import 'package:dio/dio.dart';

import '../../../core/config/env_config.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/endpoints.dart';
import '../model/login_request.dart';
import '../model/login_response.dart';

/// 登录数据源契约。ViewModel 依赖接口，测试可以注入 Fake Repository。
abstract class LoginRepository {
  /// [cancelToken] 从页面级请求处理器透传，页面销毁时可中止真实 Dio 请求。
  Future<LoginResponse> login(LoginRequest request, {CancelToken? cancelToken});
}

/// 根据编译环境在 Mock 与真实接口之间切换的 Repository 实现。
class LoginRepositoryImpl implements LoginRepository {
  LoginRepositoryImpl(this._apiService);

  final ApiService _apiService;

  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    CancelToken? cancelToken,
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
    CancelToken? cancelToken,
  }) async {
    // ApiService 统一处理基础地址、状态码、异常映射和 JSON 转换。
    final response = await _apiService.post<LoginResponse>(
      Endpoints.login,
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
