import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/home/home_providers.dart';
import 'package:riverpod_mvvm/features/home/model/home_banner.dart';
import 'package:riverpod_mvvm/features/home/repository/home_repository.dart';
import 'package:riverpod_mvvm/features/home/view_model/home_view_model.dart';

class _PendingHomeRepository implements HomeRepository {
  // 测试通过 Completer 精确等待 Repository 真正收到 CancelToken。
  final requestStarted = Completer<CancelToken>();

  @override
  Future<List<HomeBanner>> fetchBanners({CancelToken? cancelToken}) async {
    // 记录令牌后一直等待取消；若生产代码没取消，测试会无法完成。
    requestStarted.complete(cancelToken);
    await cancelToken!.whenCancel;
    throw DioException.requestCancelled(
      requestOptions: RequestOptions(path: '/home/banners'),
      reason: 'provider disposed',
    );
  }
}

void main() {
  test('disposing page provider cancels its active request', () async {
    // Arrange：override Repository，并创建独立 Riverpod 容器。
    final repository = _PendingHomeRepository();
    final container = ProviderContainer(
      overrides: [homeRepositoryProvider.overrideWith((ref) => repository)],
    );
    addTearDown(container.dispose);

    // Act 1：listen 模拟页面 watch，使 autoDispose Provider 保持存活并发起请求。
    final subscription = container.listen(homeProvider, (_, _) {});
    final request = container.read(homeProvider.notifier).loadHome();
    final cancelToken = await repository.requestStarted.future;

    // Act 2：关闭最后一个监听，等待 Riverpod 执行 dispose 微任务。
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    // Assert：Repository 收到的是已取消令牌，请求也能正常结束而非悬挂。
    expect(cancelToken.isCancelled, isTrue);
    await request;
  });
}

// 页面请求生命周期测试：使用永不主动完成的 Fake Repository，证明最后一个
// Provider 监听者离开后，ref.onDispose 会把取消信号传到 Repository。
