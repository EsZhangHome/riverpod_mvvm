// lib/features/auth/model/login_response.dart
//
// 作用：登录响应结果模型，封装登录接口返回的 token 和用户信息。
// 使用 json_serializable 生成序列化代码，与其他模型保持一致。

import 'package:json_annotation/json_annotation.dart';

import 'user_model.dart';

part 'login_response.g.dart';

/// 登录响应结果模型。
@JsonSerializable()
class LoginResponse {
  const LoginResponse({required this.token, required this.user});

  /// 鉴权令牌
  final String token;

  /// 登录用户信息。协议约定登录成功时必须返回，因此保持非空类型。
  final UserModel user;

  /// 反序列化委托给生成代码，Model 本身只声明协议字段。
  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);

  /// Repository 或缓存需要 Map 时使用生成代码，避免手写 key 出错。
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
