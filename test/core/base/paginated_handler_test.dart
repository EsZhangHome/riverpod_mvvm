// PaginatedListHandler 测试。
//
// 重点验证分页状态转移和 CancelToken 确实进入 fetchPage；这样未来接入真实
// Repository 时，不会出现“Provider 销毁了，但 Dio 请求仍在后台执行”。

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/base/paginated_handler.dart';
import 'package:riverpod_mvvm/core/base/view_state.dart';

void main() {
  test('refresh passes token and replaces the first page', () async {
    final handler = PaginatedListHandler<int>();
    addTearDown(handler.dispose);
    final states = <PaginatedListState<int>>[];

    await handler.refresh(
      fetchPage: (page, cancelToken) async {
        expect(page, 1);
        expect(identical(cancelToken, handler.cancelToken), isTrue);
        return [1, 2];
      },
      currentState: const PaginatedListState<int>(items: [99]),
      onStateChanged: states.add,
      pageSize: 2,
    );

    expect(states.first.isRefreshing, isTrue);
    expect(states.last.viewState, ViewState.success);
    expect(states.last.items, [1, 2]);
    expect(states.last.hasMore, isTrue);
  });

  test('loadMore appends data and advances page', () async {
    final handler = PaginatedListHandler<int>();
    addTearDown(handler.dispose);
    final states = <PaginatedListState<int>>[];

    await handler.loadMore(
      fetchPage: (page, _) async {
        expect(page, 2);
        return [3];
      },
      currentState: const PaginatedListState<int>(
        viewState: ViewState.success,
        items: [1, 2],
      ),
      onStateChanged: states.add,
      pageSize: 2,
    );

    expect(states.last.items, [1, 2, 3]);
    expect(states.last.page, 2);
    expect(states.last.hasMore, isFalse);
    expect(states.last.isLoadingMore, isFalse);
  });

  test(
    'dispose cancels an active page request and drops late results',
    () async {
      final handler = PaginatedListHandler<int>();
      final requestStarted = Completer<CancelToken>();
      final states = <PaginatedListState<int>>[];

      final request = handler.refresh(
        fetchPage: (page, cancelToken) async {
          requestStarted.complete(cancelToken);
          await cancelToken.whenCancel;
          return [1];
        },
        currentState: const PaginatedListState<int>(),
        onStateChanged: states.add,
      );
      final token = await requestStarted.future;
      handler.dispose();
      await request;

      expect(token.isCancelled, isTrue);
      expect(states, hasLength(1));
      expect(states.single.isRefreshing, isTrue);
    },
  );

  test('unknown errors use a user-safe message', () async {
    final handler = PaginatedListHandler<int>();
    addTearDown(handler.dispose);
    final states = <PaginatedListState<int>>[];

    await handler.refresh(
      fetchPage: (_, _) => throw StateError('database password'),
      currentState: const PaginatedListState<int>(),
      onStateChanged: states.add,
    );

    expect(states.last.viewState, ViewState.error);
    expect(states.last.errorMessage, '请求失败，请稍后重试');
    expect(states.last.errorMessage, isNot(contains('database password')));
  });
}
