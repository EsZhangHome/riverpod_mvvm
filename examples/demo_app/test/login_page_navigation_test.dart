// test/features/auth/login_page_navigation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/app/app.dart';
import 'package:riverpod_mvvm_demo/demo_route_bundle.dart';
import 'package:riverpod_mvvm_demo/navigation/demo_route_paths.dart';
import 'package:riverpod_mvvm_demo/localization/demo_strings.dart';
import 'package:riverpod_mvvm/core/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login success navigates to main page', (tester) async {
    // Arrange：清空安全存储和普通存储，模拟首次安装。
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await LocalStorage.init();

    await tester.pumpWidget(
      ProviderScope(child: MyApp(routeBundle: createDemoRouteBundle())),
    );
    await tester.pumpAndSettle();

    // Act 1：像真实用户一样输入测试值。生产登录页不在源码中预填任何凭据。
    await tester.enterText(find.byType(TextField).at(0), 'demo@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'demo-password');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('商品'), findsWidgets);
    expect(find.text('订单'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(find.text(DemoStrings.learningPathTitle), findsNothing);

    // 加购后点击购物车应进入详情页，不能再把购物车当成清空按钮。
    await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(DemoStrings.openCart));
    await tester.pumpAndSettle();
    expect(find.text(DemoStrings.cartTitle), findsOneWidget);
    expect(find.text('旗舰手机'), findsOneWidget);
    expect(find.text(DemoStrings.cartTotal(1, '5999.00')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Act 2：逐个切换 Tab，验证 StatefulNavigationShell 分支可达。
    await tester.tap(find.text(DemoStrings.orders));
    await tester.pumpAndSettle();
    expect(find.text(DemoStrings.ordersTitle), findsOneWidget);
    expect(find.text(DemoStrings.learningPathTitle), findsNothing);

    await tester.tap(find.text(DemoStrings.mine));
    await tester.pumpAndSettle();
    expect(find.text(DemoStrings.mineTitle), findsOneWidget);

    // 学习说明从业务 Tab 正文移出，只通过“我的”右上角独立入口进入。
    expect(find.text(DemoStrings.learningPathTitle), findsNothing);
    await tester.tap(find.byTooltip(DemoStrings.openRiverpodLearning));
    await tester.pumpAndSettle();
    expect(find.text(DemoStrings.learningCenterTitle), findsOneWidget);
    expect(find.text(DemoStrings.learningPathTitle), findsOneWidget);
    expect(find.text(DemoStrings.basicLearningScene), findsOneWidget);

    // /main 是兼容入口，必须明确重定向到真实的首个分支，不能落入 404。
    tester
        .element(find.text(DemoStrings.learningCenterTitle))
        .go(DemoRoutePaths.main);
    await tester.pumpAndSettle();
    expect(find.text(DemoStrings.catalogTitle), findsOneWidget);
    expect(find.text(DemoStrings.pageNotFound), findsNothing);
  });
}

// 登录到主框架的端到端 Widget 测试：覆盖会话写入、三个 Tab、购物车子路由、
// 独立学习中心以及 /main 兼容重定向，确保路由与 Riverpod 状态一起工作。
