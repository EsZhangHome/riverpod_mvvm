// test/features/home/home_view_model_test.dart
// HomeNotifier 基础成功路径测试：通过 ProviderContainer override 注入 Fake，
// 不挂载页面，也不访问网络。

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/home/home_providers.dart';
import 'package:riverpod_mvvm/features/home/model/home_banner.dart';
import 'package:riverpod_mvvm/features/home/repository/home_repository.dart';
import 'package:riverpod_mvvm/features/home/view_model/home_view_model.dart';

class FakeHomeRepository implements HomeRepository {
  @override
  Future<List<HomeBanner>> fetchBanners({CancelToken? cancelToken}) async {
    return const [HomeBanner(id: '1', title: 'Fake Banner', imageUrl: '')];
  }
}

void main() {
  test(
    'home notifier uses fake repository via ProviderContainer override',
    () async {
      // Arrange：替换 Repository，Notifier 及 AsyncRequestHandler 保持生产实现。
      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWith((ref) => FakeHomeRepository()),
        ],
      );
      addTearDown(container.dispose);

      // Act：read notifier 发送一次加载命令。
      final notifier = container.read(homeProvider.notifier);
      await notifier.loadHome();

      // Assert：成功数据已经进入 View 订阅的 HomeState。
      expect(notifier.state.banners, hasLength(1));
      expect(notifier.state.banners.first.title, 'Fake Banner');
    },
  );
}
