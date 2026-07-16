// lib/features/learning/view_model/riverpod_learning_view_model.dart
//
// 学习中心自己的 Riverpod 数据流同样遵循 MVVM：Repository Provider 负责注入，
// Notifier 管当前阶段，派生 Provider 根据阶段得到当前课程。
//
// 阅读顺序：Repository Provider -> lessonsProvider -> stageProvider
// -> currentLessonProvider -> RiverpodLearningPage。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/riverpod_lesson.dart';
import '../repository/riverpod_learning_repository.dart';

final riverpodLearningRepositoryProvider = Provider<RiverpodLearningRepository>(
  (ref) {
    // 本地实现可在测试或未来业务中 override 为 JSON/远端实现。
    return const LocalRiverpodLearningRepository();
  },
);

final riverpodLessonsProvider = Provider<List<RiverpodLesson>>((ref) {
  // 课程是只读数据，不需要 Notifier；Repository 变化时自动重新读取。
  return ref.watch(riverpodLearningRepositoryProvider).getLessons();
});

class RiverpodLessonStageNotifier extends Notifier<RiverpodLessonStage> {
  @override
  // 每次进入学习中心都从基础阶段开始。
  RiverpodLessonStage build() => RiverpodLessonStage.basic;

  /// 顶部分段按钮直接选择某一阶段。
  void select(RiverpodLessonStage stage) => state = stage;

  void previous() {
    // 边界保护放在 ViewModel，即使别的 View 调用也不会数组越界。
    if (state.index > 0) {
      state = RiverpodLessonStage.values[state.index - 1];
    }
  }

  void next() {
    // values 的声明顺序就是业务学习顺序。
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
  // 同时依赖选择状态和课程集合，任何一方变化都重新派生。
  final stage = ref.watch(riverpodLessonStageProvider);
  final lessons = ref.watch(riverpodLessonsProvider);
  // Repository 必须保证三个阶段各有一课；测试会验证切换顺序。
  return lessons.firstWhere((lesson) => lesson.stage == stage);
});
