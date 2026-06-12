// lib/features/login/repository/login_repository.dart
//
// 作用：登录数据仓库，负责执行登录请求并返回登录结果。
//
// Mock 开关：通过 EnvConfig.enableMock 控制，`flutter run --dart-define=ENV_ENABLE_MOCK=false` 切换到真实接口。

import 'package:dio/dio.dart';

import '../../../core/config/env_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/endpoints.dart';
import '../model/login_request.dart';
import '../model/login_response.dart';

abstract class LoginRepository {
  Future<LoginResponse> login(LoginRequest request, {CancelToken? cancelToken});
}

class LoginRepositoryImpl implements LoginRepository {
  LoginRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiClient.instance;

  final ApiService _apiService;

  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    CancelToken? cancelToken,
  }) async {
    if (EnvConfig.enableMock) {
      return _mockLogin(request);
    }
    return _apiLogin(request, cancelToken: cancelToken);
  }

  Future<LoginResponse> _mockLogin(LoginRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
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
    final response = await _apiService.post<LoginResponse>(
      Endpoints.login,
      data: request.toJson(),
      cancelToken: cancelToken,
      fromJson: (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }
}
