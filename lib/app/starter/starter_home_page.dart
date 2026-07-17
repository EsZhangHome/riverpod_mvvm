// 底座登录后的最小占位首页。
//
// 它不是 Demo 业务，只用于验证“启动 → 会话恢复 → 登录 → 首页 → 退出”闭环。
// 真正项目接入首页后，应连同 starter_route_bundle.dart 一起删除，而不是继承本页面。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env_config.dart';
import '../../features/auth/auth.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/navigation/route_paths.dart';
import 'starter_strings.dart';

/// 登录成功后的占位首页，同时提供退出入口验证完整认证生命周期。
///
/// 使用 [ConsumerWidget] 是因为页面需要读取 authProvider 当前用户并发送 logout 命令。
/// 页面不直接调用 SessionStore，也不手工跳转 `/login`：AuthNotifier 清除登录态后，
/// GoRouter 监听状态变化并由 AuthRouteGuard 自动完成重定向。
class StarterHomePage extends ConsumerWidget {
  /// 创建占位首页。[key] 只用于 Flutter Widget 身份识别，通常无需传入。
  const StarterHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select 只订阅用户展示信息；其他 AuthState 字段变化不会让本页无意义重建。
    final user = ref.watch(authProvider.select((state) => state.currentUser));
    final strings = StarterStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(EnvConfig.appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.message, textAlign: TextAlign.center),
              if (user != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(user.name, style: Theme.of(context).textTheme.titleMedium),
              ],
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                // 隐私中心是底座公共公开路由。真实项目删除 Starter 后，只需在自己的
                // 设置/关于页面继续导航到同一路径，不需要复制隐私状态或页面代码。
                onPressed: () => context.push(RoutePaths.privacyCenter),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: Text(strings.privacyCenter),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                // read 只发送一次退出命令，不订阅 Notifier 对象本身。
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: Text(strings.logout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
