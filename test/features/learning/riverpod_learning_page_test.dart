import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/l10n/app_strings.dart';
import 'package:riverpod_mvvm/features/learning/model/riverpod_lesson.dart';
import 'package:riverpod_mvvm/features/learning/view/riverpod_learning_page.dart';

void main() {
  testWidgets('独立学习中心在窄屏切换基础、异步和全局内容', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RiverpodLearningPage())),
    );

    expect(find.text(AppStrings.learningCenterTitle), findsOneWidget);
    expect(find.text(AppStrings.basicLearningScene), findsOneWidget);

    final stageSelector = find.byWidgetPredicate(
      (widget) => widget is SegmentedButton<RiverpodLessonStage>,
    );

    await tester.tap(
      find.descendant(
        of: stageSelector,
        matching: find.text(AppStrings.learningAsync),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.asyncLearningScene), findsOneWidget);

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
