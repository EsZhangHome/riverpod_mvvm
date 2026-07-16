// lib/shared/state/paginated_handler.dart
//
// 页码分页的通用请求协调器。它只处理请求互斥、取消、状态流转和基于最新状态
// 合并，不假设业务 Model 有 id。需要 cursor 或按 id 去重时由业务提供 mergePage。

import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_observer.dart';
import '../../core/network/request_cancellation.dart';
import '../errors/failure_message_resolver.dart';
import '../localization/user_message.dart';
import 'view_state.dart';

/// 页码分页页面的不可变状态。
class PaginatedListState<T> {
  /// 创建一份页码分页状态快照。
  ///
  /// 参数说明：
  /// - [viewState]：整个内容区状态，首次加载一般使用 loading；
  /// - [errorMessage]：安全的用户提示；已有数据时加载更多失败可只展示轻提示；
  /// - [items]：当前完整列表，会复制为不可变 List，外部无法原地修改；
  /// - [page]：当前已成功合入列表的页码，默认 1；
  /// - [hasMore]：是否可能还有下一页；
  /// - [isRefreshing]：下拉刷新是否进行中；
  /// - [isLoadingMore]：底部追加是否进行中。
  ///
  /// 两个 loading bool 分开存在，是因为页面可能保留旧列表并分别展示顶部刷新指示器
  /// 或底部加载器；它们不是 [viewState] 的重复字段。
  PaginatedListState({
    this.viewState = ViewState.idle,
    this.errorMessage,
    List<T> items = const [],
    this.page = 1,
    this.hasMore = true,
    this.isRefreshing = false,
    this.isLoadingMore = false,
  }) : items = List<T>.unmodifiable(items);

  /// 首屏内容状态。
  final ViewState viewState;

  /// 最近一次失败的可展示文案，成功刷新/加载更多后会清空。
  final UserMessage? errorMessage;

  /// 当前已经合并完成的不可变列表。
  final List<T> items;

  /// 最后一次成功加载的页码。
  final int page;

  /// 是否允许继续尝试下一页。
  final bool hasMore;

  /// 是否正在执行覆盖/合并第一页的刷新。
  final bool isRefreshing;

  /// 是否正在追加下一页。
  final bool isLoadingMore;

  /// 创建新状态，未传参数沿用旧值。
  ///
  /// [items] 一旦传入，构造函数仍会复制为不可变 List；因此 Riverpod 订阅者不会因
  /// 外部继续修改原 List 而在没有 state 赋值时悄悄变化。
  PaginatedListState<T> copyWith({
    ViewState? viewState,
    UserMessage? errorMessage,
    bool clearErrorMessage = false,
    List<T>? items,
    int? page,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
  }) {
    return PaginatedListState<T>(
      viewState: viewState ?? this.viewState,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// 获取指定 [page] 的业务数据；[cancelToken] 必须继续传给 Repository/ApiService。
typedef PageFetcher<T> =
    Future<List<T>> Function(int page, RequestCancellationToken cancelToken);

/// 在异步返回的最后时刻读取 ViewModel 最新分页状态，避免使用过期闭包快照。
typedef PageStateReader<T> = PaginatedListState<T> Function();

/// 把协调器生成的新状态写回 ViewModel，通常实现为 `(value) => state = value`。
typedef PageStateWriter<T> = void Function(PaginatedListState<T> state);

/// 自定义列表合并规则。
///
/// [currentItems] 是请求返回时的最新列表，[incomingItems] 是新页数据；返回最终列表。
/// 可在这里按业务 id 去重、保留实时推送项或应用排序规则。
typedef PageMerger<T> =
    List<T> Function(List<T> currentItems, List<T> incomingItems);

/// 管理一个页码分页列表的请求生命周期。
class PaginatedListHandler<T> {
  /// 是否已随 Provider 销毁。
  bool _isDisposed = false;

  /// loadMore 互斥标志，防止滚动监听在一帧内触发多次下一页请求。
  bool _isLoadingMore = false;

  /// 请求代数。刷新/加载/销毁都会递增，旧请求即使晚返回也不能覆盖新状态。
  int _generation = 0;

  /// 当前请求取消令牌；refresh 会取消旧令牌，dispose 会取消最后一个令牌。
  RequestCancellationToken? _activeToken;

  /// 下拉刷新优先级高于加载更多：它会取消当前请求并启动新一代请求。
  ///
  /// 参数说明：
  /// - [fetchPage]：获取页面数据的函数；refresh 固定请求第 1 页，并把本次 token
  ///   传给它，Repository 必须继续透传才能真正取消网络；
  /// - [readState]：每次需要合并前读取 ViewModel 最新 state，而不是捕获调用时旧值；
  /// - [onStateChanged]：把协调器计算出的新状态写回 ViewModel；
  /// - [mergeRefresh]：可选第一页合并策略。不传时新第一页完全替换当前 items；若
  ///   页面含实时推送/本地草稿，可传函数保留这些项；
  /// - [pageSize]：请求约定的单页数量，只用于推断 hasMore。返回数量小于它表示末页。
  ///
  /// pageSize 必须与 Repository 实际请求大小一致且大于 0；若后端直接返回 hasMore
  /// 或 nextCursor，应在 feature 内使用对应分页模型，不要套用本页码协调器猜测。
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
    final token = RequestCancellationToken();
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
          clearErrorMessage: true,
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
  ///
  /// 参数含义与 [refresh] 一致，但 [mergePage] 默认执行
  /// `[...currentItems, ...incomingItems]`。如果后端可能跨页返回重复数据，业务必须
  /// 提供按稳定 id 去重的 mergePage；通用层不知道 T 的主键，不能擅自判断。
  ///
  /// 以下情况会静默返回且不请求：Handler 已销毁、正在加载更多、正在刷新、或
  /// hasMore=false。这样滚动回调可以放心高频调用，不需要在 Widget 再复制互斥逻辑。
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
    final token = RequestCancellationToken();
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
          clearErrorMessage: true,
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

  /// 判断异步结果是否仍属于当前有效请求。
  ///
  /// [generation] 是请求开始时保存的代数，[token] 是该请求专属令牌；只有 Handler
  /// 未销毁、代数仍最新且 token 未取消时才允许回写状态。
  bool _isCurrent(int generation, RequestCancellationToken token) {
    return !_isDisposed && generation == _generation && !token.isCancelled;
  }

  /// 同时识别主动 token 取消和网络层已经归一化的取消失败。
  ///
  /// 这里不识别 DioException，因为共享状态层不应该知道具体网络库。ApiClient 已把
  /// Dio 的取消异常转换成 AppFailure；Fake 数据源则可直接取消传入的令牌。
  bool _isCancellation(Object error, RequestCancellationToken token) {
    return token.isCancelled || (error is AppFailure && error.isCancellation);
  }

  /// 上报非预期编程/解析异常；已经分类的 AppFailure 只交给页面正常展示。
  void _reportUnexpected(Object error, StackTrace stackTrace) {
    FailureObserver.reportIfNeeded(error, stackTrace);
  }

  /// 结束协调器生命周期并取消当前分页请求。
  ///
  /// 应在拥有它的 Notifier 中注册 `ref.onDispose(handler.dispose)`。本方法可重复调用；
  /// generation 递增还能阻止无法真正取消的异步数据源在稍后回写旧结果。
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _generation++;
    _activeToken?.cancel('paginator disposed');
    _activeToken = null;
  }
}
