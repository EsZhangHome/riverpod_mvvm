// lib/features/profile/view/profile_page.dart
//
// 作用：个人中心页面，展示用户详细信息和退出登录入口。
//
// 页面执行顺序：首帧后读取当前会话用户并加载详情；build 同时 watch
// AuthState 和 ProfileState；详情未返回时显示基础用户；退出时清理全局会话。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:riverpod_mvvm/shared/ui/page_shell.dart';
import '../../../localization/demo_strings.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';
import 'package:riverpod_mvvm/shared/theme/app_spacing.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/shared/ui/user_info_card.dart';
import '../view_model/profile_view_model.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // build 之前不触发业务命令，等待首帧后再安全读取 Provider。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authState = ref.read(authProvider);
        ref.read(profileProvider.notifier).loadProfile(authState.currentUser);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // AuthState 是全局兜底，ProfileState 是页面级详情。
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final user = profileState.user ?? authState.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text(DemoStrings.profile)),
      body: PageShell(
        // PageShell 只解释 ViewState，不创建或持有 ViewModel。
        viewState: profileState.viewState,
        errorMessage: profileState.errorMessage,
        onRetry: () => ref
            .read(profileProvider.notifier)
            .loadProfile(authState.currentUser),
        builder: (context) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              UserInfoCard(name: user?.name, email: user?.email),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () => _logout(),
                icon: const Icon(Icons.logout),
                label: const Text(DemoStrings.logout),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    // 先清内存和本地 token，再替换到登录路由。
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go(RoutePaths.login);
    }
  }
}
