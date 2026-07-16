// test/features/auth/login_page_navigation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/app/app.dart';
import 'package:riverpod_mvvm/shared/localization/app_strings.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';
import 'package:riverpod_mvvm/core/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login success navigates to main page', (tester) async {
    // Arrange：清空安全存储和普通存储，模拟首次安装。
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await LocalStorage.init();

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // Act 1：使用页面默认账号点击登录，等待 AuthNotifier 和 GoRouter 完成。
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('商品'), findsWidgets);
    expect(find.text('订单'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(find.text(AppStrings.learningPathTitle), findsNothing);

    // 加购后点击购物车应进入详情页，不能再把购物车当成清空按钮。
    await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.openCart));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.cartTitle), findsOneWidget);
    expect(find.text('旗舰手机'), findsOneWidget);
    expect(find.text(AppStrings.cartTotal(1, '5999.00')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Act 2：逐个切换 Tab，验证 StatefulNavigationShell 分支可达。
    await tester.tap(find.text(AppStrings.orders));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.ordersTitle), findsOneWidget);
    expect(find.text(AppStrings.learningPathTitle), findsNothing);

    await tester.tap(find.text(AppStrings.mine));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.mineTitle), findsOneWidget);

    // 学习说明从业务 Tab 正文移出，只通过“我的”右上角独立入口进入。
    expect(find.text(AppStrings.learningPathTitle), findsNothing);
    await tester.tap(find.byTooltip(AppStrings.openRiverpodLearning));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.learningCenterTitle), findsOneWidget);
    expect(find.text(AppStrings.learningPathTitle), findsOneWidget);
    expect(find.text(AppStrings.basicLearningScene), findsOneWidget);

    // /main 是兼容入口，必须明确重定向到真实的首个分支，不能落入 404。
    tester
        .element(find.text(AppStrings.learningCenterTitle))
        .go(RoutePaths.main);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.catalogTitle), findsOneWidget);
    expect(find.text(AppStrings.pageNotFound), findsNothing);
  });
}

// 登录到主框架的端到端 Widget 测试：覆盖会话写入、三个 Tab、购物车子路由、
// 独立学习中心以及 /main 兼容重定向，确保路由与 Riverpod 状态一起工作。
