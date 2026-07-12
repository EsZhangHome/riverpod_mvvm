// lib/shared/widgets/user_info_card.dart
//
// 作用：用户信息卡片组件，展示头像、昵称、邮箱。MinePage 和 ProfilePage 共用。
//
// 使用方式：
// ```dart
// UserInfoCard(user: user)
// ```

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// 用户信息卡片。
///
/// 当前展示头像占位 + 昵称 + 邮箱。
/// 接入真实头像后，将 CircleAvatar 替换为实际图片组件。
class UserInfoCard extends StatelessWidget {
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
