// lib/features/auth/model/auth_session.dart
//
// 登录会话必须作为一个整体保存。把 token 和用户分别写入两个存储，会产生
// “token 已写入、用户写入失败”的半登录状态。

import 'user_model.dart';

/// 已通过认证、可以恢复的完整会话。
class AuthSession {
  /// 创建一份完整、可持久化的认证会话。
  ///
  /// - [token]：之后写入 Authorization Header 的 access token，必须是非空有效值；
  /// - [user]：与该 token 属于同一登录人的用户快照。
  ///
  /// Dart 类型只能保证 token 非 null，无法保证非空；网络解析和恢复存储时会继续
  /// 校验。业务代码应由 AuthNotifier 统一创建，不要在页面中零散拼装。
  const AuthSession({required this.token, required this.user});

  /// 访问令牌。属于敏感凭据，不能写入普通日志、Crash 文本或非安全缓存。
  final String token;

  /// 当前用户快照，用于展示身份和派生用户级 Provider key。
  final UserModel user;

  /// 转成安全存储中的 JSON 结构。
  ///
  /// `version` 是存储协议版本，不是 App 版本；以后字段结构不兼容时应增加版本并在
  /// [fromJson] 中迁移，不能直接改变旧版本含义。
  Map<String, dynamic> toJson() => {
    'version': 1,
    'token': token,
    'user': user.toJson(),
  };

  /// 从安全存储恢复完整会话。
  ///
  /// [json] 必须含受支持的 version、非空字符串 token 和 Map 类型 user；任一条件
  /// 不满足都会抛 [FormatException]。AuthNotifier 会捕获并清理损坏数据，避免 App
  /// 永久停在恢复状态，因此这里不返回“半有效”对象。
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
