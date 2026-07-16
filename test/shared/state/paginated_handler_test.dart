// PaginatedListHandler 测试。
//
// 测试除了基本分页，还覆盖两个容易被忽略的并发问题：请求完成时必须读取最新
// State；刷新开始后，旧的“加载更多”结果不能再覆盖新列表。

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/shared/state/paginated_handler.dart';
import 'package:riverpod_mvvm/shared/state/view_state.dart';

void main() {
  test('refresh passes a token and replaces the first page', () async {
    final handler = PaginatedListHandler<int>();
    addTearDown(handler.dispose);
    var current = PaginatedListState<int>(items: [99]);
    final states = <PaginatedListState<int>>[];

    await handler.refresh(
      fetchPage: (page, cancelToken) async {
        expect(page, 1);
        expect(cancelToken.isCancelled, isFalse);
        return [1, 2];
      },
      readState: () => current,
      onStateChanged: (next) {
        current = next;
        states.add(next);
      },
      pageSize: 2,
    );

    expect(states.first.isRefreshing, isTrue);
    expect(current.viewState, ViewState.success);
    expect(current.items, [1, 2]);
    expect(current.hasMore, isTrue);
  });

  test('loadMore appends data and advances page', () async {
    final handler = PaginatedListHandler<int>();
    addTearDown(handler.dispose);
    var current = PaginatedListState<int>(
      viewState: ViewState.success,
      items: [1, 2],
    );

    await handler.loadMore(
      fetchPage: (page, _) async {
        expect(page, 2);
        return [3];
      },
      readState: () => current,
      onStateChanged: (next) => current = next,
      pageSize: 2,
    );

    expect(current.items, [1, 2, 3]);
    expect(current.page, 2);
    expect(current.hasMore, isFalse);
    expect(current.isLoadingMore, isFalse);
  });

  test(
    'loadMore merges into the latest state instead of a stale snapshot',
    () async {
      final handler = PaginatedListHandler<int>();
      addTearDown(handler.dispose);
      final response = Completer<List<int>>();
      var current = PaginatedListState<int>(
        viewState: ViewState.success,
        items: [1],
      );

      final request = handler.loadMore(
        fetchPage: (_, _) => response.future,
        readState: () => current,
        onStateChanged: (next) => current = next,
      );
      // 模拟请求期间 WebSocket 推送或乐观更新写入的新数据。
      current = current.copyWith(items: [1, 99]);
      response.complete([2]);
      await request;

      expect(current.items, [1, 99, 2]);
    },
  );

  test('refresh cancels active loadMore and drops its late result', () async {
    final handler = PaginatedListHandler<int>();
    addTearDown(handler.dispose);
    final loadMoreStarted = Completer<CancelToken>();
    var current = PaginatedListState<int>(
      viewState: ViewState.success,
      items: [1],
    );

    final loadMore = handler.loadMore(
      fetchPage: (_, token) async {
        loadMoreStarted.complete(token);
        await token.whenCancel;
        return [2];
      },
      readState: () => current,
      onStateChanged: (next) => current = next,
    );
    final oldToken = await loadMoreStarted.future;
    await handler.refresh(
      fetchPage: (_, _) async => [10],
      readState: () => current,
      onStateChanged: (next) => current = next,
    );
    await loadMore;

    expect(oldToken.isCancelled, isTrue);
    expect(current.items, [10]);
  });

  test(
    'dispose cancels an active page request and drops late results',
    () async {
      final handler = PaginatedListHandler<int>();
      final requestStarted = Completer<CancelToken>();
      var current = PaginatedListState<int>();
      final states = <PaginatedListState<int>>[];

      final request = handler.refresh(
        fetchPage: (page, cancelToken) async {
          requestStarted.complete(cancelToken);
          await cancelToken.whenCancel;
          return [1];
        },
        readState: () => current,
        onStateChanged: (next) {
          current = next;
          states.add(next);
        },
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
    var current = PaginatedListState<int>();

    await handler.refresh(
      fetchPage: (_, _) => throw StateError('database password'),
      readState: () => current,
      onStateChanged: (next) => current = next,
    );

    expect(current.viewState, ViewState.error);
    expect(current.errorMessage, '请求失败，请稍后重试');
    expect(current.errorMessage, isNot(contains('database password')));
  });
}
