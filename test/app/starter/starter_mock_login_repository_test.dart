// Starter Mock 登录与组合测试。
//
// 本文件随 app/starter 一起删除。它验证模拟数据本身、取消语义，以及开发配置下
// buildStarterRoot 确实通过 Provider override 选择 Mock，而不是让真实仓库读开关。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/starter/starter.dart';
import 'package:riverpod_mvvm/app/starter/starter_mock_login_repository.dart';
import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

void main() {
  test('starter mock returns a model without accessing a backend', () async {
    const repository = StarterMockLoginRepository(
      simulatedDelay: Duration.zero,
    );

    final response = await repository.login(
      const LoginRequest(account: 'reader@example.com', password: 'secret'),
    );

    expect(response.token, startsWith('mock_token_'));
    expect(response.user.name, 'Flutter User');
    expect(response.user.email, 'reader@example.com');
  });

  test(
    'starter mock stops its simulated delay when request is cancelled',
    () async {
      const repository = StarterMockLoginRepository(
        simulatedDelay: Duration(seconds: 1),
      );
      final cancellation = RequestCancellationToken();

      final request = repository.login(
        const LoginRequest(account: 'reader', password: 'secret'),
        cancelToken: cancellation,
      );
      cancellation.cancel('test disposed');

      await expectLater(request, throwsA(isA<RequestCancellationFailure>()));
    },
  );

  testWidgets('starter root injects mock repository in development', (
    tester,
  ) async {
    LoginRepository? selectedRepository;

    await tester.pumpWidget(
      buildStarterRoot(
        Consumer(
          builder: (context, ref, child) {
            selectedRepository = ref.watch(loginRepositoryProvider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(selectedRepository, isA<StarterMockLoginRepository>());
  });
}
