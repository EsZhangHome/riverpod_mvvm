// 公共 Toast / SnackBar 行为测试。
//
// Toast 重点验证根 Overlay、三种位置、替换和自动消失；SnackBar 重点验证带操作按钮
// 的场景。两者测试分开，防止以后内部实现又被混成同一种组件。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/shared/ui/app_snack_bar.dart';
import 'package:riverpod_mvvm/shared/ui/app_toast.dart';

void main() {
  tearDown(AppToast.dismiss);

  testWidgets('toast defaults to center and supports top and bottom', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('page'))),
    );
    final context = tester.element(find.byType(Scaffold));

    const cases = [
      (AppToastPosition.center, Alignment.center),
      (AppToastPosition.top, Alignment.topCenter),
      (AppToastPosition.bottom, Alignment.bottomCenter),
    ];

    for (final (position, expectedAlignment) in cases) {
      AppToast.showInfo(context, position.name, position: position);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(position.name), findsOneWidget);
      final align = tester.widget<Align>(
        find.byKey(const ValueKey('app_toast_alignment')),
      );
      expect(align.alignment, expectedAlignment);

      AppToast.dismiss();
      await tester.pump();
    }
  });

  testWidgets('new toast replaces old toast and auto dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('page'))),
    );
    final context = tester.element(find.byType(Scaffold));

    AppToast.showInfo(context, 'first');
    await tester.pump();
    AppToast.showSuccess(
      context,
      'second',
      displayDuration: const Duration(milliseconds: 200),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);

    // 200ms 停留结束后再推进 160ms 退出动画，OverlayEntry 应被真正移除。
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('second'), findsNothing);
  });

  testWidgets('snack bar keeps bottom action scenario separate from toast', (
    tester,
  ) async {
    var restored = false;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('page'))),
    );
    final context = tester.element(find.byType(Scaffold));

    AppSnackBar.show(
      context,
      message: '商品已删除',
      actionLabel: '撤销',
      onAction: () => restored = true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('商品已删除'), findsOneWidget);
    await tester.tap(find.text('撤销'));
    expect(restored, isTrue);
  });
}
