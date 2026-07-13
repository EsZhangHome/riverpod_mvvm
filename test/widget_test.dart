// test/widget_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/app.dart';
import 'package:riverpod_mvvm/core/l10n/app_strings.dart';
import 'package:riverpod_mvvm/core/router/route_paths.dart';
import 'package:riverpod_mvvm/core/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app starts at login page when there is no token', (
    tester,
  ) async {
    // Arrange：明确设置空存储，避免测试受本机历史数据影响。
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await LocalStorage.init();

    // Act：挂载完整 App，ProviderScope、AuthNotifier、GoRouter 都走生产组装路径。
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsWidgets);
    expect(find.text('MVVM Demo'), findsOneWidget);

    // 未登录时，未来新增的任意 /main/* 深层路由也必须统一被守卫拦截。
    tester
        .element(find.text(AppStrings.login).first)
        .go('${RoutePaths.mainOrders}/order-1');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.login), findsWidgets);
    expect(find.text(AppStrings.pageNotFound), findsNothing);

    // 学习中心同样属于登录后的功能，未登录深链访问必须被拦截。
    tester
        .element(find.text(AppStrings.login).first)
        .go(RoutePaths.riverpodLearning);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.login), findsWidgets);
    expect(find.text(AppStrings.learningCenterTitle), findsNothing);
  });

  testWidgets('app does not paint login page while restoring saved session', (
    tester,
  ) async {
    // Arrange：同时准备 token 和用户 JSON，模拟上一次已登录。
    SharedPreferences.setMockInitialValues({
      'current_user':
          '{"id":"1","name":"Test User","email":"test@example.com"}',
    });
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'saved_token'});
    await LocalStorage.init();

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump();

    expect(find.text('登录'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
  });
}

// App 根级 Widget 测试：关注启动期会话恢复和路由守卫，不测试具体业务列表。
