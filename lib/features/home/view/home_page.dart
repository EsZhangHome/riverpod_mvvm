// lib/features/home/view/home_page.dart
//
// 作用：首页 Tab 页面，展示 Banner 列表。
//
// 迁移说明（Provider → Riverpod）：
// - ConsumerStatefulWidget 替代 BasePage + ChangeNotifierProvider
// - locator<HomeViewModel>() → homeProvider
// - context.read<ThemeProvider>() → ref.read(themeProvider)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/base/base_page.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../global/theme_provider.dart';
import '../view_model/home_view_model.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(homeProvider.notifier).loadHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.home),
        actions: [
          IconButton(
            tooltip: AppStrings.switchTheme,
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: PageShell(
        viewState: state.viewState,
        errorMessage: state.errorMessage,
        onRetry: () => ref.read(homeProvider.notifier).loadHome(),
        builder: (context) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: state.banners.length,
            separatorBuilder: (_, i) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final banner = state.banners[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(banner.title),
                  subtitle: const Text(AppStrings.mockBannerTips),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
