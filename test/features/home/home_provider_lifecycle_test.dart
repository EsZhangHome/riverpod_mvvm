import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/providers/repositories.dart';
import 'package:riverpod_mvvm/features/home/model/home_banner.dart';
import 'package:riverpod_mvvm/features/home/repository/home_repository.dart';
import 'package:riverpod_mvvm/features/home/view_model/home_view_model.dart';

class _PendingHomeRepository implements HomeRepository {
  final requestStarted = Completer<CancelToken>();

  @override
  Future<List<HomeBanner>> fetchBanners({CancelToken? cancelToken}) async {
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
    final repository = _PendingHomeRepository();
    final container = ProviderContainer(
      overrides: [homeRepositoryProvider.overrideWith((ref) => repository)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(homeProvider, (_, _) {});
    final request = container.read(homeProvider.notifier).loadHome();
    final cancelToken = await repository.requestStarted.future;

    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(cancelToken.isCancelled, isTrue);
    await request;
  });
}
