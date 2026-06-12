// lib/features/login/model/login_response.dart
//
// 作用：登录响应结果模型，封装登录接口返回的 token 和用户信息。
// 使用 json_serializable 生成序列化代码，与其他模型保持一致。

import 'package:json_annotation/json_annotation.dart';

import '../../../shared/models/user_model.dart';

part 'login_response.g.dart';

/// 登录响应结果模型。
@JsonSerializable()
class LoginResponse {
  const LoginResponse({required this.token, required this.user});

  /// 鉴权令牌
  final String token;

  /// 登录用户信息
  @JsonKey(defaultValue: null)
  final UserModel user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginResponse && other.token == token && other.user == user;

  @override
  int get hashCode => Object.hash(token, user);

  @override
  String toString() => 'LoginResponse(token: $token, user: $user)';
}
