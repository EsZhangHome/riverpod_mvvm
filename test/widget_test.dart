// test/widget_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_mvvm/app.dart';
import 'package:provider_mvvm/core/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app starts at login page when there is no token', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await LocalStorage.init();

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsWidgets);
    expect(find.text('MVVM Demo'), findsOneWidget);
  });

  testWidgets('app does not paint login page while restoring saved session', (
    tester,
  ) async {
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
