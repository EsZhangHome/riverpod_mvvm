// Starter 专用的本地登录数据源。
//
// 该实现只帮助刚克隆底座的开发者在没有后端时跑通登录闭环，不属于认证 Feature。
// 接入真实首页并删除 app/starter 后，本文件和 Provider override 会一起删除。

import 'dart:async';

import '../../core/network/request_cancellation.dart';
import '../../features/auth/auth.dart';

/// 不访问网络的 Starter 登录仓库。
final class StarterMockLoginRepository implements LoginRepository {
  /// 创建 Mock 仓库。
  ///
  /// [simulatedDelay] 用来演示登录按钮 loading，默认 600ms；测试可以传 Duration.zero
  /// 避免等待。它属于构造依赖，而不是全局开关，因此每个实例行为确定、容易测试。
  const StarterMockLoginRepository({
    this.simulatedDelay = const Duration(milliseconds: 600),
  });

  final Duration simulatedDelay;

  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  }) async {
    await _waitForSimulation(cancelToken);

    // 复用正式 Model 的 fromJson，Mock 不另造一套字段协议。账号仅用于生成演示用户，
    // 密码不会持久化、输出日志或写进返回对象。
    return LoginResponse.fromJson({
      'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      'user': {
        'id': '1',
        'name': request.account.contains('@') ? 'Flutter User' : 'Mobile User',
        'email': request.account.contains('@')
            ? request.account
            : 'user@example.com',
        'avatarUrl': null,
      },
    });
  }

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
