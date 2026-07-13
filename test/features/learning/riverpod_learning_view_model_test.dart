import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/learning/model/riverpod_lesson.dart';
import 'package:riverpod_mvvm/features/learning/view_model/riverpod_learning_view_model.dart';

void main() {
  test('学习中心按照基础、异步、全局顺序切换课程', () {
    // Arrange：每个测试使用独立容器，结束时释放 autoDispose Provider。
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // currentRiverpodLessonProvider 是 autoDispose，listen 模拟页面 watch。
    final subscription = container.listen(
      currentRiverpodLessonProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    // Assert 1：build 默认返回基础阶段。
    expect(
      container.read(currentRiverpodLessonProvider).stage,
      RiverpodLessonStage.basic,
    );

    // Act 1：调用 next，派生课程应同步切到异步。
    container.read(riverpodLessonStageProvider.notifier).next();
    expect(
      container.read(currentRiverpodLessonProvider).stage,
      RiverpodLessonStage.async,
    );

    // Act 2：再次 next 到全局。
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

// 学习中心 ViewModel 测试：不挂载 Widget，直接通过 ProviderContainer 验证
// Notifier 边界保护和派生 currentRiverpodLessonProvider 的联动。
