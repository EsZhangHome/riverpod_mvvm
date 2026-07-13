// test/shared/widgets/app_network_image_test.dart
//
// 不请求真实图片，只验证空地址时会展示统一错误占位。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/shared/widgets/app_network_image.dart';

void main() {
  testWidgets('app network image shows fallback when url is empty', (
    tester,
  ) async {
    // Arrange + Act：空 URL 不触发真实网络加载，直接走组件的错误占位分支。
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppNetworkImage(imageUrl: '', width: 100, height: 80),
        ),
      ),
    );

    // Assert：所有页面共享同一个不可用图片视觉反馈。
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
