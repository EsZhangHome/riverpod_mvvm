// lib/shared/state/paginated_handler.dart
//
// 页码分页的通用请求协调器。它只处理请求互斥、取消、状态流转和基于最新状态
// 合并，不假设业务 Model 有 id。需要 cursor 或按 id 去重时由业务提供 mergePage。

import 'package:dio/dio.dart';

import '../../core/errors/app_failure.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/crash_reporter.dart';
import '../errors/failure_message_resolver.dart';
import 'view_state.dart';

/// 页码分页页面的不可变状态。
class PaginatedListState<T> {
  PaginatedListState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    List<T> items = const [],
    this.page = 1,
    this.hasMore = true,
    this.isRefreshing = false,
    this.isLoadingMore = false,
  }) : items = List<T>.unmodifiable(items);

  final ViewState viewState;
  final String errorMessage;
  final List<T> items;
  final int page;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;

  PaginatedListState<T> copyWith({
    ViewState? viewState,
    String? errorMessage,
    List<T>? items,
    int? page,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
  }) {
    return PaginatedListState<T>(
      viewState: viewState ?? this.viewState,
      errorMessage: errorMessage ?? this.errorMessage,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

typedef PageFetcher<T> =
    Future<List<T>> Function(int page, CancelToken cancelToken);
typedef PageStateReader<T> = PaginatedListState<T> Function();
typedef PageStateWriter<T> = void Function(PaginatedListState<T> state);
typedef PageMerger<T> =
    List<T> Function(List<T> currentItems, List<T> incomingItems);

/// 管理一个页码分页列表的请求生命周期。
class PaginatedListHandler<T> {
  bool _isDisposed = false;
  bool _isLoadingMore = false;
  int _generation = 0;
  CancelToken? _activeToken;

  /// 下拉刷新优先级高于加载更多：它会取消当前请求并启动新一代请求。
  Future<void> refresh({
    required PageFetcher<T> fetchPage,
    required PageStateReader<T> readState,
    required PageStateWriter<T> onStateChanged,
    PageMerger<T>? mergeRefresh,
    int pageSize = 20,
  }) async {
    if (_isDisposed) return;

    final generation = ++_generation;
    _activeToken?.cancel('superseded by refresh');
    final token = CancelToken();
    _activeToken = token;
    _isLoadingMore = false;

    final initial = readState();
    onStateChanged(
      initial.copyWith(viewState: ViewState.loading, isRefreshing: true),
    );

    try {
      final incoming = await fetchPage(1, token);
      if (!_isCurrent(generation, token)) return;
      final latest = readState();
      final items = mergeRefresh?.call(latest.items, incoming) ?? incoming;
      onStateChanged(
        latest.copyWith(
          viewState: items.isEmpty ? ViewState.empty : ViewState.success,
          items: items,
          page: 1,
          hasMore: incoming.length >= pageSize,
          isRefreshing: false,
          isLoadingMore: false,
          errorMessage: '',
        ),
      );
    } catch (error, stackTrace) {
      if (!_isCurrent(generation, token) || _isCancellation(error, token)) {
        return;
      }
      _reportUnexpected(error, stackTrace);
      final latest = readState();
      onStateChanged(
        latest.copyWith(
          viewState: latest.items.isEmpty ? ViewState.error : ViewState.success,
          errorMessage: FailureMessageResolver.resolve(error),
          isRefreshing: false,
        ),
      );
    } finally {
      if (identical(_activeToken, token)) _activeToken = null;
    }
  }

  /// 追加下一页。完成时基于最新 State 合并，避免覆盖期间的实时推送或乐观更新。
  Future<void> loadMore({
    required PageFetcher<T> fetchPage,
    required PageStateReader<T> readState,
    required PageStateWriter<T> onStateChanged,
    PageMerger<T>? mergePage,
    int pageSize = 20,
  }) async {
    final initial = readState();
    if (_isDisposed ||
        _isLoadingMore ||
        initial.isRefreshing ||
        !initial.hasMore) {
      return;
    }

    _isLoadingMore = true;
    final generation = ++_generation;
    final token = CancelToken();
    _activeToken = token;
    final nextPage = initial.page + 1;
    onStateChanged(initial.copyWith(isLoadingMore: true));

    try {
      final incoming = await fetchPage(nextPage, token);
      if (!_isCurrent(generation, token)) return;
      final latest = readState();
      final items =
          mergePage?.call(latest.items, incoming) ??
          [...latest.items, ...incoming];
      onStateChanged(
        latest.copyWith(
          items: items,
          page: nextPage,
          hasMore: incoming.length >= pageSize,
          isLoadingMore: false,
          errorMessage: '',
        ),
      );
    } catch (error, stackTrace) {
      if (!_isCurrent(generation, token) || _isCancellation(error, token)) {
        return;
      }
      _reportUnexpected(error, stackTrace);
      onStateChanged(
        readState().copyWith(
          errorMessage: FailureMessageResolver.resolve(error),
          isLoadingMore: false,
        ),
      );
    } finally {
      if (generation == _generation) _isLoadingMore = false;
      if (identical(_activeToken, token)) _activeToken = null;
    }
  }

  bool _isCurrent(int generation, CancelToken token) {
    return !_isDisposed && generation == _generation && !token.isCancelled;
  }

  bool _isCancellation(Object error, CancelToken token) {
    return token.isCancelled ||
        (error is ApiException && error.isCancelled) ||
        error is DioException && error.type == DioExceptionType.cancel;
  }

  void _reportUnexpected(Object error, StackTrace stackTrace) {
    if (error is! AppFailure) CrashReporter.report(error, stackTrace);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _generation++;
    _activeToken?.cancel('paginator disposed');
    _activeToken = null;
  }
}
