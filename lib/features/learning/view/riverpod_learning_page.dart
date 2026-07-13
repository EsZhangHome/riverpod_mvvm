// lib/features/learning/view/riverpod_learning_page.dart
//
// 独立学习中心。业务 Tab 不展示教学导航；这里统一展示学习路径、源码片段，
// 并提供进入对应业务场景的按钮。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/riverpod_learning_panel.dart';
import '../model/riverpod_lesson.dart';
import '../view_model/riverpod_learning_view_model.dart';

class RiverpodLearningPage extends ConsumerWidget {
  const RiverpodLearningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(riverpodLessonStageProvider);
    final lesson = ref.watch(currentRiverpodLessonProvider);
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
            onPressed: () => context.go(_practiceRoute(stage)),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text(AppStrings.learningOpenPractice),
          ),
        ],
      ),
    );
  }

  RiverpodLearningStage _panelStage(RiverpodLessonStage stage) =>
      switch (stage) {
        RiverpodLessonStage.basic => RiverpodLearningStage.basic,
        RiverpodLessonStage.async => RiverpodLearningStage.async,
        RiverpodLessonStage.global => RiverpodLearningStage.global,
      };

  String _practiceRoute(RiverpodLessonStage stage) => switch (stage) {
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
