// lib/features/auth/model/user_model.dart
//
// 作用：用户数据模型，定义用户的基本信息字段。
//
// UserModel 是 Auth 模块拥有的会话领域模型。
// 其他业务需要用户信息时，只通过 features/auth/auth.dart 公共入口引用。
//
// 设计要点：
// 1. 使用 json_serializable 生成 fromJson / toJson，减少手写字段映射错误
// 2. 通过 @JsonKey(defaultValue: ...) 给关键字段提供兜底默认值
// 3. 提供 copyWith 方法，方便局部更新用户信息（如只改昵称或头像）
// 4. 手写 operator== 和 hashCode，不依赖 equatable/freezed 等外部包
// 5. 使用 const 构造函数，所有字段都是 final，确保不可变性

import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// 用户数据模型。
///
/// 代表一个登录用户的基本信息，所有需要展示用户信息的模块都可以使用。
@JsonSerializable()
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  /// 用户唯一标识
  @JsonKey(defaultValue: '')
  final String id;

  /// 用户昵称/姓名
  @JsonKey(defaultValue: '')
  final String name;

  /// 用户邮箱
  @JsonKey(defaultValue: '')
  final String email;

  /// 用户头像 URL，可能为空
  final String? avatarUrl;

  /// 从 JSON Map 创建 UserModel 实例。
  ///
  /// 字段映射代码由 json_serializable 生成。
  /// 缺失或为 null 的必填字符串会使用 `@JsonKey` 中的默认值；如果后端返回了
  /// 错误的数据类型，生成代码会抛出解析异常，再由网络层转换成统一的协议错误。
  /// 这里不悄悄吞掉类型错误，是为了尽早发现服务端协议与客户端模型不一致。
  ///
  /// 示例：
  /// ```dart
  /// final user = UserModel.fromJson({
  ///   'id': '1',
  ///   'name': 'Tom',
  ///   'email': 'tom@example.com',
  ///   'avatarUrl': 'https://example.com/avatar.jpg',
  /// });
  /// ```
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return _$UserModelFromJson(json);
  }

  /// 创建 UserModel 的副本，只修改指定的字段。
  ///
  /// 使用场景：
  /// - 用户修改昵称后，更新内存中的用户信息
  /// - 用户上传新头像后，更新 avatarUrl
  ///
  /// 示例：
  /// ```dart
  /// final updatedUser = user.copyWith(name: 'New Name');
  /// ```
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// 序列化为 JSON Map。
  ///
  /// 当前由 SessionStore 与 token 一起序列化为完整安全会话。
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// 相等性比较：所有字段相等才认为两个 UserModel 相等。
  ///
  /// 不依赖 equatable 或 freezed，手写实现减少外部依赖。
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserModel &&
            other.id == id &&
            other.name == name &&
            other.email == email &&
            other.avatarUrl == avatarUrl;
  }

  /// 基于所有字段计算哈希值。
  @override
  int get hashCode => Object.hash(id, name, email, avatarUrl);
}
