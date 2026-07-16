// lib/features/auth/model/auth_session.dart
//
// 登录会话必须作为一个整体保存。把 token 和用户分别写入两个存储，会产生
// “token 已写入、用户写入失败”的半登录状态。

import 'user_model.dart';

/// 已通过认证、可以恢复的完整会话。
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final UserModel user;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'token': token,
    'user': user.toJson(),
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported auth session version');
    }
    final token = json['token'];
    final user = json['user'];
    if (token is! String || token.isEmpty || user is! Map) {
      throw const FormatException('Incomplete auth session');
    }
    return AuthSession(
      token: token,
      user: UserModel.fromJson(Map<String, dynamic>.from(user)),
    );
  }
}
