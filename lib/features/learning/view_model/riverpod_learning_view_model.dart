// lib/features/learning/view_model/riverpod_learning_view_model.dart
//
// 学习中心自己的 Riverpod 数据流同样遵循 MVVM：Repository Provider 负责注入，
// Notifier 管当前阶段，派生 Provider 根据阶段得到当前课程。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/riverpod_lesson.dart';
import '../repository/riverpod_learning_repository.dart';

final riverpodLearningRepositoryProvider = Provider<RiverpodLearningRepository>(
  (ref) {
    return const LocalRiverpodLearningRepository();
  },
);

final riverpodLessonsProvider = Provider<List<RiverpodLesson>>((ref) {
  return ref.watch(riverpodLearningRepositoryProvider).getLessons();
});

class RiverpodLessonStageNotifier extends Notifier<RiverpodLessonStage> {
  @override
  RiverpodLessonStage build() => RiverpodLessonStage.basic;

  void select(RiverpodLessonStage stage) => state = stage;

  void previous() {
    if (state.index > 0) {
      state = RiverpodLessonStage.values[state.index - 1];
    }
  }

  void next() {
    if (state.index < RiverpodLessonStage.values.length - 1) {
      state = RiverpodLessonStage.values[state.index + 1];
    }
  }
}

// 页面退出后不需要保留阅读位置，因此学习中心自己的选择状态使用 autoDispose。
final riverpodLessonStageProvider =
    NotifierProvider.autoDispose<
      RiverpodLessonStageNotifier,
      RiverpodLessonStage
    >(RiverpodLessonStageNotifier.new);

final currentRiverpodLessonProvider = Provider.autoDispose<RiverpodLesson>((
  ref,
) {
  final stage = ref.watch(riverpodLessonStageProvider);
  final lessons = ref.watch(riverpodLessonsProvider);
  return lessons.firstWhere((lesson) => lesson.stage == stage);
});
