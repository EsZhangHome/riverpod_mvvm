import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/l10n/app_strings.dart';
import 'package:riverpod_mvvm/features/learning/model/riverpod_lesson.dart';
import 'package:riverpod_mvvm/features/learning/view/riverpod_learning_page.dart';

void main() {
  testWidgets('独立学习中心在窄屏切换基础、异步和全局内容', (tester) async {
    // Arrange：固定窄屏，并在结束时恢复测试全局窗口配置。
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 挂载 ProviderScope，使用与生产页面相同的 Provider 创建路径。
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RiverpodLearningPage())),
    );

    // Assert 1：Notifier 的默认阶段是 basic。
    expect(find.text(AppStrings.learningCenterTitle), findsOneWidget);
    expect(find.text(AppStrings.basicLearningScene), findsOneWidget);

    // 泛型 Widget 的运行时类型包含 RiverpodLessonStage，使用 predicate 精确查找。
    final stageSelector = find.byWidgetPredicate(
      (widget) => widget is SegmentedButton<RiverpodLessonStage>,
    );

    // Act 1：通过真实 UI 切到异步阶段。
    await tester.tap(
      find.descendant(
        of: stageSelector,
        matching: find.text(AppStrings.learningAsync),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.asyncLearningScene), findsOneWidget);

    // Act 2：继续切到全局阶段，并检查最后一次构建没有布局异常。
    await tester.tap(
      find.descendant(
        of: stageSelector,
        matching: find.text(AppStrings.learningGlobal),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.globalLearningScene), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

// 学习中心 Widget 测试：在窄屏上操作真实 SegmentedButton，确认 View 发出的
// 阶段命令会让派生课程从基础切到异步、全局，并且没有 RenderFlex 溢出。
