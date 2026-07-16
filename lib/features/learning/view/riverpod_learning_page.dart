// lib/features/learning/view/riverpod_learning_page.dart
//
// 独立学习中心。业务 Tab 不展示教学导航；这里统一展示学习路径、源码片段，
// 并提供进入对应业务场景的按钮。
//
// 页面执行顺序：
// 1. watch 当前阶段与由其派生的课程；
// 2. 分段按钮/上一站/下一站 read Notifier 修改阶段；
// 3. 学习面板展示结构化说明，代码卡展示 Repository 提供的源码；
// 4. “进入实战”根据阶段 go 到商品、订单或我的 Tab；
// 5. 页面离开后 autoDispose 清理阅读阶段。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/localization/app_strings.dart';
import '../../../shared/navigation/route_paths.dart';
import '../../../shared/theme/app_spacing.dart';
import './widgets/riverpod_learning_panel.dart';
import '../model/riverpod_lesson.dart';
import '../view_model/riverpod_learning_view_model.dart';

class RiverpodLearningPage extends ConsumerWidget {
  const RiverpodLearningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // stage 控制按钮状态，lesson 是根据 stage 自动派生的课程内容。
    final stage = ref.watch(riverpodLessonStageProvider);
    final lesson = ref.watch(currentRiverpodLessonProvider);
    // Notifier 引用只用于发送命令，不需要 watch。
    final notifier = ref.read(riverpodLessonStageProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.learningCenterTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SegmentedButton<RiverpodLessonStage>(
            segments: const [
              ButtonSegment(
                value: RiverpodLessonStage.basic,
                label: Text(AppStrings.learningBasic),
              ),
              ButtonSegment(
                value: RiverpodLessonStage.async,
                label: Text(AppStrings.learningAsync),
              ),
              ButtonSegment(
                value: RiverpodLessonStage.global,
                label: Text(AppStrings.learningGlobal),
              ),
            ],
            selected: {stage},
            // SegmentedButton 保证集合中只有一个选中值。
            onSelectionChanged: (selection) =>
                notifier.select(selection.single),
          ),
          const SizedBox(height: AppSpacing.lg),
          RiverpodLearningPanel(
            stage: _panelStage(stage),
            scene: lesson.scene,
            apis: lesson.apis,
            dataFlow: lesson.dataFlow,
            interaction: lesson.interaction,
            codeEntry: lesson.codeEntry,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.learningCodeExamples,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < lesson.codeExamples.length; index++)
            _CodeExampleCard(
              example: lesson.codeExamples[index],
              // 默认展开第一段，让用户进入页面就能看到实际代码。
              initiallyExpanded: index == 0,
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: stage == RiverpodLessonStage.basic
                      ? null
                      : notifier.previous,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(AppStrings.learningPrevious),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: stage == RiverpodLessonStage.global
                      ? null
                      : notifier.next,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(AppStrings.learningNext),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            // go 切换到 StatefulShellRoute 对应业务入口，不保留教学页在业务栈中。
            onPressed: () => context.go(_practiceRoute(stage)),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text(AppStrings.learningOpenPractice),
          ),
        ],
      ),
    );
  }

  RiverpodLearningStage _panelStage(RiverpodLessonStage stage) =>
      // 业务 Model 枚举不依赖共享 Widget 枚举，由 View 完成展示层映射。
      switch (stage) {
        RiverpodLessonStage.basic => RiverpodLearningStage.basic,
        RiverpodLessonStage.async => RiverpodLearningStage.async,
        RiverpodLessonStage.global => RiverpodLearningStage.global,
      };

  String _practiceRoute(RiverpodLessonStage stage) => switch (stage) {
    // 每一阶段都落到真实可操作业务，而不是另一个静态说明页面。
    RiverpodLessonStage.basic => RoutePaths.mainHome,
    RiverpodLessonStage.async => RoutePaths.mainOrders,
    RiverpodLessonStage.global => RoutePaths.mainMine,
  };
}

class _CodeExampleCard extends StatelessWidget {
  const _CodeExampleCard({
    required this.example,
    required this.initiallyExpanded,
  });

  final RiverpodCodeExample example;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    // Theme 颜色只影响展示，不进入课程 Model。
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(example.title),
        children: [
          Container(
            width: double.infinity,
            color: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SingleChildScrollView(
              // 代码保持原始缩进，过长行横向滚动而不是强制换行。
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                example.code,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
