// lib/shared/state/paginated_handler.dart
//
// 作用：分页列表处理器，封装 refresh/loadMore 的通用逻辑。
//
// 使用场景：任何需要下拉刷新 + 上拉加载更多的列表页面。
//
// 使用方式：
// ```dart
// class MyListNotifier extends Notifier<MyListState> {
//   late final _paginator = PaginatedListHandler<ItemModel>();
//
//   @override
//   MyListState build() {
//     ref.onDispose(() => _paginator.dispose());
//     return MyListState();
//   }
//
//   Future<void> refresh() async {
//     await _paginator.refresh(
//       fetchPage: (page, cancelToken) => ref
//           .read(repoProvider)
//           .fetchItems(page: page, cancelToken: cancelToken),
//       currentState: state,
//       pageSize: 20,
//       onStateChanged: (s) => state = s,
//     );
//   }
//
//   Future<void> loadMore() async {
//     await _paginator.loadMore(
//       fetchPage: (page, cancelToken) => ref
//           .read(repoProvider)
//           .fetchItems(page: page, cancelToken: cancelToken),
//       currentState: state,
//       pageSize: 20,
//       onStateChanged: (s) => state = s,
//     );
//   }
// }
// ```

import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import 'view_state.dart';

/// 分页列表状态。
///
/// 包含 ViewState（用于页面级的 loading/error/empty 展示）
/// 和分页信息（page、hasMore、isRefreshing、isLoadingMore）。
class PaginatedListState<T> {
  const PaginatedListState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
    this.isRefreshing = false,
    this.isLoadingMore = false,
  });

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

/// 分页列表处理器。
///
/// 封装了下拉刷新、上拉加载更多、请求防抖、CancelToken 管理。
/// 每个分页列表 Notifier 在 build() 中创建一个实例。
class PaginatedListHandler<T> {
  bool _isRequesting = false;
  bool _isDisposed = false;
  final CancelToken cancelToken = CancelToken();

  /// 下拉刷新：重置为第 1 页，清空旧数据，重新加载。
  ///
  /// [fetchPage]：获取指定页数据的闭包。处理器把自己持有的取消令牌强制传入，
  /// 调用者再继续透传给 Repository，避免只在表面上支持请求取消。
  /// [currentState]：当前状态（用于判断 hasMore、page 等）
  /// [onStateChanged]：状态变更回调（通常直接赋值 state = newState）
  /// [pageSize]：每页条数，默认 20
  Future<void> refresh({
    required Future<List<T>> Function(int page, CancelToken cancelToken)
    fetchPage,
    required PaginatedListState<T> currentState,
    required void Function(PaginatedListState<T> state) onStateChanged,
    int pageSize = 20,
  }) async {
    if (_isRequesting || _isDisposed || cancelToken.isCancelled) return;

    _isRequesting = true;
    onStateChanged(
      currentState.copyWith(viewState: ViewState.loading, isRefreshing: true),
    );

    try {
      final items = await fetchPage(1, cancelToken);
      if (_isDisposed || cancelToken.isCancelled) return;
      final hasMore = items.length >= pageSize;
      onStateChanged(
        currentState.copyWith(
          viewState: items.isEmpty ? ViewState.empty : ViewState.success,
          items: items,
          page: 1,
          hasMore: hasMore,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      if (_isDisposed ||
          cancelToken.isCancelled ||
          (e is ApiException && e.isCancelled)) {
        return;
      }
      onStateChanged(
        currentState.copyWith(
          viewState: currentState.items.isEmpty
              ? ViewState.error
              : ViewState.success, // 有旧数据时不覆盖为 error
          errorMessage: _toUserMessage(e),
          isRefreshing: false,
        ),
      );
    } finally {
      _isRequesting = false;
    }
  }

  /// 上拉加载更多：追加下一页数据。
  Future<void> loadMore({
    required Future<List<T>> Function(int page, CancelToken cancelToken)
    fetchPage,
    required PaginatedListState<T> currentState,
    required void Function(PaginatedListState<T> state) onStateChanged,
    int pageSize = 20,
  }) async {
    if (_isRequesting || _isDisposed || cancelToken.isCancelled) return;
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    _isRequesting = true;
    final nextPage = currentState.page + 1;
    onStateChanged(currentState.copyWith(isLoadingMore: true));

    try {
      final newItems = await fetchPage(nextPage, cancelToken);
      if (_isDisposed || cancelToken.isCancelled) return;
      final hasMore = newItems.length >= pageSize;
      onStateChanged(
        currentState.copyWith(
          items: [...currentState.items, ...newItems],
          page: nextPage,
          hasMore: hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      if (_isDisposed ||
          cancelToken.isCancelled ||
          (e is ApiException && e.isCancelled)) {
        return;
      }
      onStateChanged(
        currentState.copyWith(
          errorMessage: _toUserMessage(e),
          isLoadingMore: false,
        ),
      );
    } finally {
      _isRequesting = false;
    }
  }

  /// 释放资源。
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    if (!cancelToken.isCancelled) cancelToken.cancel('paginator disposed');
  }

  /// 把基础设施异常收敛成 View 可以直接展示的文案。
  /// DioException 等未知技术异常不能通过 toString 泄漏到页面。
  String _toUserMessage(Object error) {
    if (error is BusinessException) return error.userMessage;
    if (error is ApiException) return error.message;
    return '请求失败，请稍后重试';
  }
}
