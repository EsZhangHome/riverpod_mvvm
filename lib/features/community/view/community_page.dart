// lib/features/community/view/community_page.dart
//
// 作用：社区 Tab 页面，展示社区帖子列表。
//
// 迁移说明（Provider → Riverpod）：
// - ConsumerStatefulWidget 替代 BasePage

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/base/base_page.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../view_model/community_view_model.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(communityProvider.notifier).loadCommunity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.community)),
      body: PageShell(
        viewState: state.viewState,
        errorMessage: state.errorMessage,
        onRetry: () => ref.read(communityProvider.notifier).loadCommunity(),
        builder: (context) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: state.posts.length,
            separatorBuilder: (_, i) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.forum_outlined),
                  title: Text(state.posts[index]),
                  subtitle: const Text(AppStrings.communityMockTips),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
