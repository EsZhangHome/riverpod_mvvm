// LoginNotifier 单元测试。
//
// 本文件只验证 ViewModel 的职责：表单校验、命令参数和 LoginState。SignIn 用例通过
// Provider override 替换，因此这里不创建 Repository、SessionStore 或 AuthNotifier；
// 它们之间的协作顺序由 sign_in_use_case_test.dart 单独验证。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/api_exception.dart';
import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import 'package:riverpod_mvvm/features/auth/application/sign_in_use_case.dart';
import 'package:riverpod_mvvm/features/auth/auth_composition.dart';
import 'package:riverpod_mvvm/features/auth/model/login_request.dart';
import 'package:riverpod_mvvm/features/auth/view_model/login_view_model.dart';
import 'package:riverpod_mvvm/shared/localization/user_message.dart';
import 'package:riverpod_mvvm/shared/state/view_state.dart';

final class _FakeSignIn implements SignIn {
  _FakeSignIn({this.result = SignInResult.authenticated, this.error});

  final SignInResult result;
  final Object? error;
  LoginRequest? receivedRequest;
  RequestCancellationToken? receivedCancelToken;
  var callCount = 0;

  @override
  Future<SignInResult> call(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  }) async {
    callCount++;
    receivedRequest = request;
    receivedCancelToken = cancelToken;
    if (error case final error?) throw error;
    return result;
  }
}

ProviderContainer _createContainer(_FakeSignIn signIn) {
  return ProviderContainer(
    overrides: [signInProvider.overrideWithValue(signIn)],
  );
}

void main() {
  test('valid form sends one command and publishes success state', () async {
    final signIn = _FakeSignIn();
    final container = _createContainer(signIn);
    addTearDown(container.dispose);

    final notifier = container.read(loginProvider.notifier);
    await notifier.login(' test@example.com ', '123456');

    expect(signIn.callCount, 1);
    expect(signIn.receivedRequest?.account, 'test@example.com');
    expect(signIn.receivedRequest?.password, '123456');
    expect(signIn.receivedCancelToken, isNotNull);
    expect(notifier.state.viewState, ViewState.success);
  });

  test('empty input fails before calling sign-in use case', () async {
    final signIn = _FakeSignIn();
    final container = _createContainer(signIn);
    addTearDown(container.dispose);

    final notifier = container.read(loginProvider.notifier);
    await notifier.login('  ', '');

    expect(signIn.callCount, 0);
    expect(notifier.state.viewState, ViewState.idle);
    expect(notifier.state.feedbackMessage?.key, UserMessageKey.enterAccount);
    expect(notifier.state.feedbackId, 1);
  });

  test('business error becomes a trusted dynamic feedback message', () async {
    final signIn = _FakeSignIn(
      error: BusinessException(code: 1001, userMessage: '账号已冻结'),
    );
    final container = _createContainer(signIn);
    addTearDown(container.dispose);

    final notifier = container.read(loginProvider.notifier);
    await notifier.login('user', 'password');

    expect(notifier.state.viewState, ViewState.idle);
    expect(notifier.state.feedbackMessage?.text, '账号已冻结');
    expect(notifier.state.feedbackId, 1);
  });

  test('same validation error increments feedback id every time', () async {
    final signIn = _FakeSignIn();
    final container = _createContainer(signIn);
    addTearDown(container.dispose);
    final notifier = container.read(loginProvider.notifier);

    await notifier.login('', '');
    final firstFeedbackId = notifier.state.feedbackId;
    await notifier.login('', '');

    expect(firstFeedbackId, 1);
    expect(notifier.state.feedbackId, 2);
    expect(signIn.callCount, 0);
  });

  test('password is validated separately and sent without trimming', () async {
    final signIn = _FakeSignIn();
    final container = _createContainer(signIn);
    addTearDown(container.dispose);
    final notifier = container.read(loginProvider.notifier);

    await notifier.login(' user@example.com ', '');
    expect(notifier.state.feedbackMessage?.key, UserMessageKey.enterPassword);
    expect(signIn.callCount, 0);

    await notifier.login(' user@example.com ', ' pass word ');
    expect(signIn.receivedRequest?.account, 'user@example.com');
    expect(signIn.receivedRequest?.password, ' pass word ');
  });

  test('session activation failure becomes typed storage feedback', () async {
    final signIn = _FakeSignIn(result: SignInResult.sessionActivationFailed);
    final container = _createContainer(signIn);
    addTearDown(container.dispose);

    final notifier = container.read(loginProvider.notifier);
    await notifier.login('user@example.com', 'password');

    expect(notifier.state.viewState, ViewState.idle);
    expect(notifier.state.feedbackMessage?.key, UserMessageKey.storageError);
  });
}
