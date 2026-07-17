// Demo 应用专用的本地登录实现。
//
// 为什么 Demo 自己保留一份 Mock：
// - 独立 Demo 是企业底座的消费者，不能反向依赖根项目 app/starter 中的实现；
// - 删除 examples/demo_app 时，本文件会一起删除，正式 App 不会携带教学账号或 Mock；
// - 登录 Feature 仍只依赖 LoginRepository 抽象，不需要在业务代码里判断环境。

import 'dart:async';

import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

/// 不访问网络的 Demo 登录仓库。
///
/// 用户输入任意非空账号和密码后，登录 ViewModel 会调用本实现并得到一个模拟会话。
/// [simulatedDelay] 让学习应用能够展示按钮的 loading 状态；测试可传零来立即完成。
final class DemoMockLoginRepository implements LoginRepository {
  const DemoMockLoginRepository({
    this.simulatedDelay = const Duration(milliseconds: 600),
  });

  final Duration simulatedDelay;

  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  }) async {
    await _waitForSimulation(cancelToken);

    // 密码只参与登录页的非空校验，不会保存、打印或写进模拟响应。
    return LoginResponse.fromJson({
      'token': 'demo_token_${DateTime.now().millisecondsSinceEpoch}',
      'user': {
        'id': 'demo-user',
        'name': request.account.contains('@') ? 'Flutter User' : 'Mobile User',
        'email': request.account.contains('@')
            ? request.account
            : 'user@example.com',
        'avatarUrl': null,
      },
    });
  }

  /// 模拟可取消的请求等待，行为与真实网络请求的页面生命周期保持一致。
  Future<void> _waitForSimulation(RequestCancellationToken? cancelToken) async {
    if (cancelToken == null) {
      await Future<void>.delayed(simulatedDelay);
      return;
    }
    if (cancelToken.isCancelled) {
      throw RequestCancellationFailure(cancelToken.reason);
    }

    final completer = Completer<void>();
    final timer = Timer(simulatedDelay, completer.complete);
    final registration = cancelToken.listen((reason) {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(RequestCancellationFailure(reason));
      }
    });
    try {
      await completer.future;
    } finally {
      timer.cancel();
      registration.dispose();
    }
  }
}
