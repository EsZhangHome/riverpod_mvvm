import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/l10n/app_strings.dart';
import 'package:riverpod_mvvm/shared/widgets/riverpod_learning_panel.dart';

void main() {
  testWidgets('学习面板按统一结构展示路线和当前阶段', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RiverpodLearningPanel(
              stage: RiverpodLearningStage.async,
              scene: '订单场景',
              apis: 'AsyncNotifierProvider',
              dataFlow: 'Repository → ViewModel → View',
              interaction: '下拉刷新',
              codeEntry: 'features/orders',
            ),
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.learningPathTitle), findsOneWidget);
    expect(find.text(AppStrings.learningBasic), findsOneWidget);
    expect(find.text(AppStrings.learningAsync), findsOneWidget);
    expect(find.text(AppStrings.learningGlobal), findsOneWidget);
    expect(find.text('第 2 站 · 异步'), findsOneWidget);
    expect(find.text(AppStrings.learningScene), findsOneWidget);
    expect(find.text(AppStrings.learningApis), findsOneWidget);
    expect(find.text(AppStrings.learningDataFlow), findsOneWidget);
    expect(find.text(AppStrings.learningInteraction), findsOneWidget);
    expect(find.text(AppStrings.learningCodeEntry), findsOneWidget);
    expect(find.text('订单场景'), findsOneWidget);
    expect(find.text('AsyncNotifierProvider'), findsOneWidget);
    expect(find.text('Repository → ViewModel → View'), findsOneWidget);
    expect(find.text('下拉刷新'), findsOneWidget);
    expect(find.text('features/orders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
