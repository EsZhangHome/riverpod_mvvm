// lib/features/profile/view/profile_page.dart
//
// 作用：个人中心页面，展示用户详细信息和退出登录入口。
//
// 迁移说明（Provider → Riverpod）：
// - context.watch/read<AuthProvider>() → ref.watch/read(authProvider)
// - locator<ProfileViewModel>() → profileProvider

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/base_page.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../global/auth_provider.dart';
import '../../../shared/widgets/user_info_card.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authState = ref.read(authProvider);
        ref.read(profileProvider.notifier).loadProfile(authState.currentUser);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final user = profileState.user ?? authState.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profile)),
      body: PageShell(
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
                label: const Text(AppStrings.logout),
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
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go(RoutePaths.login);
    }
  }
}
