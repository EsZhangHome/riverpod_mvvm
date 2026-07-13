import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/learning/model/riverpod_lesson.dart';
import 'package:riverpod_mvvm/features/learning/view_model/riverpod_learning_view_model.dart';

void main() {
  test('学习中心按照基础、异步、全局顺序切换课程', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // currentRiverpodLessonProvider 是 autoDispose，listen 模拟页面 watch。
    final subscription = container.listen(
      currentRiverpodLessonProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    expect(
      container.read(currentRiverpodLessonProvider).stage,
      RiverpodLessonStage.basic,
    );

    container.read(riverpodLessonStageProvider.notifier).next();
    expect(
      container.read(currentRiverpodLessonProvider).stage,
      RiverpodLessonStage.async,
    );

    container.read(riverpodLessonStageProvider.notifier).next();
    expect(
      container.read(currentRiverpodLessonProvider).stage,
      RiverpodLessonStage.global,
    );

    // 到达末尾后 next 不越界；previous 返回异步阶段。
    container.read(riverpodLessonStageProvider.notifier).next();
    expect(
      container.read(currentRiverpodLessonProvider).stage,
      RiverpodLessonStage.global,
    );
    container.read(riverpodLessonStageProvider.notifier).previous();
    expect(
      container.read(currentRiverpodLessonProvider).stage,
      RiverpodLessonStage.async,
    );
  });
}
