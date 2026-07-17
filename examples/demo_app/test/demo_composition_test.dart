import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm_demo/app/demo_composition.dart';
import 'package:riverpod_mvvm_demo/app/demo_mock_login_repository.dart';

void main() {
  testWidgets('development Demo injects its local login repository', (
    tester,
  ) async {
    LoginRepository? selectedRepository;

    await tester.pumpWidget(
      buildDemoRoot(
        Consumer(
          builder: (context, ref, child) {
            selectedRepository = ref.watch(loginRepositoryProvider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(selectedRepository, isA<DemoMockLoginRepository>());
  });

  test('Demo mock login does not access the placeholder backend', () async {
    const repository = DemoMockLoginRepository(simulatedDelay: Duration.zero);

    final response = await repository.login(
      const LoginRequest(account: 'reader@example.com', password: 'secret'),
    );

    expect(response.token, startsWith('demo_token_'));
    expect(response.user.email, 'reader@example.com');
  });
}
