// test/features/login/login_page_navigation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_mvvm/app.dart';
import 'package:provider_mvvm/core/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login success navigates to main page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await LocalStorage.init();

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsWidgets);
    expect(find.text('社区'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
  });
}
