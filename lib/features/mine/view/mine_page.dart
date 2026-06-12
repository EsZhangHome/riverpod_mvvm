// lib/features/mine/view/mine_page.dart
//
// 作用：我的 Tab 页面，展示用户信息和退出登录入口。
//
// 迁移说明（Provider → Riverpod）：
// - context.watch<AuthProvider>() → ref.watch(authProvider)
// - context.read<AuthProvider>().logout() → ref.read(authProvider.notifier).logout()

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/base_page.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../global/auth_provider.dart';
import '../../../shared/widgets/user_info_card.dart';
import '../view_model/mine_view_model.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authState = ref.read(authProvider);
        ref.read(mineProvider.notifier).loadMine(authState.currentUser);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final mineState = ref.watch(mineProvider);
    final user = mineState.user ?? authState.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.mine)),
      body: PageShell(
        viewState: mineState.viewState,
        errorMessage: mineState.errorMessage,
        onRetry: () =>
            ref.read(mineProvider.notifier).loadMine(authState.currentUser),
        builder: (context) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              UserInfoCard(name: user?.name, email: user?.email),
              const SizedBox(height: 24),
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
