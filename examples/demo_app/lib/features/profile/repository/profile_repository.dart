// lib/features/profile/repository/profile_repository.dart
//
// 作用：个人中心数据仓库，负责获取用户详细资料。
//
// Mock 开关：通过 EnvConfig.enableMock 控制。
// Profile 是保留的未来功能示例，依然遵循 ViewModel -> Repository -> ApiService。

import 'package:riverpod_mvvm/core/config/env_config.dart';
import 'package:riverpod_mvvm/core/network/api_service.dart';
import 'package:riverpod_mvvm/core/network/api_exception.dart';
import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import '../../../core/demo_endpoints.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

abstract class ProfileRepository {
  /// fallbackUser 让 Mock 或详情请求失败场景可以复用当前会话中的基础资料。
  Future<UserModel> fetchProfile(
    UserModel fallbackUser, {
    RequestCancellationToken? cancelToken,
  });
}

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._apiService);

  final ApiService _apiService;

  @override
  Future<UserModel> fetchProfile(
    UserModel fallbackUser, {
    RequestCancellationToken? cancelToken,
  }) async {
    // 编译期开关决定数据源，页面不写 if/else。
    if (EnvConfig.enableMock) {
      return _mockProfile(fallbackUser);
    }
    return _apiProfile(cancelToken: cancelToken);
  }

  Future<UserModel> _mockProfile(UserModel fallbackUser) async {
    // 模拟请求耗时后返回不可变会话用户。
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return fallbackUser;
  }

  Future<UserModel> _apiProfile({RequestCancellationToken? cancelToken}) async {
    // ApiService 负责解析，Repository 负责拒绝成功响应中的空业务数据。
    final response = await _apiService.get<UserModel>(
      DemoEndpoints.profile,
      cancelToken: cancelToken,
      fromJson: (json) => UserModel.fromJson(json as Map<String, dynamic>),
    );
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
