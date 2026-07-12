// lib/features/profile/repository/profile_repository.dart
//
// 作用：个人中心数据仓库，负责获取用户详细资料。
//
// Mock 开关：通过 EnvConfig.enableMock 控制。

import 'package:dio/dio.dart';

import '../../../core/config/env_config.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/endpoints.dart';
import '../../../shared/models/user_model.dart';

abstract class ProfileRepository {
  Future<UserModel> fetchProfile(
    UserModel fallbackUser, {
    CancelToken? cancelToken,
  });
}

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._apiService);

  final ApiService _apiService;

  @override
  Future<UserModel> fetchProfile(
    UserModel fallbackUser, {
    CancelToken? cancelToken,
  }) async {
    if (EnvConfig.enableMock) {
      return _mockProfile(fallbackUser);
    }
    return _apiProfile(cancelToken: cancelToken);
  }

  Future<UserModel> _mockProfile(UserModel fallbackUser) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return fallbackUser;
  }

  Future<UserModel> _apiProfile({CancelToken? cancelToken}) async {
    final response = await _apiService.get<UserModel>(
      Endpoints.profile,
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
