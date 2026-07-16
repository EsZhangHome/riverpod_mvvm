import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/shared/localization/app_strings.dart';
import 'package:riverpod_mvvm/features/learning/view/widgets/riverpod_learning_panel.dart';

void main() {
  testWidgets('学习面板按统一结构展示路线和当前阶段', (tester) async {
    // Arrange：使用小屏尺寸，防止三个阶段徽章横向溢出。
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 注入一组最小异步课程文案；组件本身不需要 ProviderScope。
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

    // Assert：先检查公共路线，再检查当前阶段和五块外部内容。
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
    // 最后读取 Flutter 捕获的布局异常，确保窄屏没有 overflow。
    expect(tester.takeException(), isNull);
  });
}

// 纯展示组件测试：不创建 Provider，只验证外部传入课程内容能按固定五段结构渲染，
// 同时覆盖基础/异步/全局路线标识和 320px 窄屏布局。
