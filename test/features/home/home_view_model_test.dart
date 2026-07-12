// test/features/home/home_view_model_test.dart
//
// 迁移说明：get_it locator → Riverpod ProviderContainer overrides

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/providers/repositories.dart';
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
      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWith((ref) => FakeHomeRepository()),
        ],
      );

      final notifier = container.read(homeProvider.notifier);
      await notifier.loadHome();

      expect(notifier.state.banners, hasLength(1));
      expect(notifier.state.banners.first.title, 'Fake Banner');
    },
  );
}
