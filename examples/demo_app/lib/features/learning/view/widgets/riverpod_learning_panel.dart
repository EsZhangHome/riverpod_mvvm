// lib/features/learning/view/widgets/riverpod_learning_panel.dart
//
// 独立学习中心使用的展示组件。它只接收课程数据，不读取任何 Provider，避免
// 通用 Widget 反向依赖 learning 业务层；阶段选择仍由页面 ViewModel 管理。

import 'package:flutter/material.dart';

import '../../../../localization/demo_strings.dart';
import 'package:riverpod_mvvm/shared/theme/app_spacing.dart';

enum RiverpodLearningStage { basic, async, global }

/// 把每一站统一组织成“场景 → API → 数据流 → 可操作 UI → 代码入口”。
///
/// 读者可以先在页面完成操作，再按照代码入口依次阅读
/// Model / Repository / ViewModel / View，对照观察状态从哪里来、由谁修改。
class RiverpodLearningPanel extends StatelessWidget {
  const RiverpodLearningPanel({
    super.key,
    required this.stage,
    required this.scene,
    required this.apis,
    required this.dataFlow,
    required this.interaction,
    required this.codeEntry,
  });

  /// 当前高亮的展示阶段。
  final RiverpodLearningStage stage;

  /// 五块内容由外部课程 Model 提供，组件不保存业务状态。
  final String scene;
  final String apis;
  final String dataFlow;
  final String interaction;
  final String codeEntry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DemoStrings.learningPathTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              DemoStrings.learningPathDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                // 枚举顺序固定展示“基础 -> 异步 -> 全局”。
                for (final item in RiverpodLearningStage.values) ...[
                  Expanded(
                    child: _StageBadge(
                      label: _stageLabel(item),
                      selected: item == stage,
                    ),
                  ),
                  if (item != RiverpodLearningStage.values.last)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: colorScheme.outline,
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              DemoStrings.learningCurrentStage(
                stage.index + 1,
                _stageLabel(stage),
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: AppSpacing.xl),
            _LearningItem(
              icon: Icons.storefront_outlined,
              label: DemoStrings.learningScene,
              content: scene,
            ),
            _LearningItem(
              icon: Icons.api_outlined,
              label: DemoStrings.learningApis,
              content: apis,
            ),
            _LearningItem(
              icon: Icons.account_tree_outlined,
              label: DemoStrings.learningDataFlow,
              content: dataFlow,
            ),
            _LearningItem(
              icon: Icons.touch_app_outlined,
              label: DemoStrings.learningInteraction,
              content: interaction,
            ),
            _LearningItem(
              icon: Icons.code,
              label: DemoStrings.learningCodeEntry,
              content: codeEntry,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  String _stageLabel(RiverpodLearningStage value) => switch (value) {
    RiverpodLearningStage.basic => DemoStrings.learningBasic,
    RiverpodLearningStage.async => DemoStrings.learningAsync,
    RiverpodLearningStage.global => DemoStrings.learningGlobal,
  };
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // AnimatedContainer 只做高亮过渡，不承担阶段切换事件。
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected ? colorScheme.primaryContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _LearningItem extends StatelessWidget {
  const _LearningItem({
    required this.icon,
    required this.label,
    required this.content,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String content;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // 每个条目采用相同的图标、标题、正文结构，保证三站阅读节奏一致。
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
