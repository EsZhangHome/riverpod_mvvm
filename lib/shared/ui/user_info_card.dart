// lib/shared/ui/user_info_card.dart
//
// 作用：用户信息卡片组件，展示头像、昵称、邮箱。账户页、侧边栏等位置都可复用。
//
// 使用方式：
// ```dart
// UserInfoCard(user: user)
// ```

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// 用户信息卡片。
///
/// 当前展示头像占位 + 昵称 + 邮箱。
/// 接入真实头像后，将 CircleAvatar 替换为实际图片组件。
class UserInfoCard extends StatelessWidget {
  /// 创建用户摘要卡片。
  ///
  /// - [name]：可空展示名称；null 时显示 `-`；
  /// - [email]：可空邮箱；null 时显示 `-`；
  /// - [key]：可选 Widget 身份键。
  ///
  /// 这里刻意接收展示值而不是 AuthState/Ref，使纯 UI 组件不依赖认证模块，也更容易
  /// 在其他 feature 和 Widget 测试中复用。
  const UserInfoCard({super.key, this.name, this.email});

  /// 用户昵称，为 null 时显示 '-'
  final String? name;

  /// 用户邮箱，为 null 时显示 '-'
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 16),
            Text(name ?? '-', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(email ?? '-'),
          ],
        ),
      ),
    );
  }
}
