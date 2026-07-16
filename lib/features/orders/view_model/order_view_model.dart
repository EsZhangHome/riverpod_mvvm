// lib/features/orders/view_model/order_view_model.dart
//
// 订单 ViewModel 展示一组能够协同工作的异步 Riverpod 场景：
// - Provider 注入可替换的 Repository；
// - AsyncNotifier 管初载、分页、创建、乐观更新和失败回滚；
// - Notifier 管同步筛选；
// - 派生 Provider 组合列表与筛选，不保存重复状态；
// - FutureProvider.family 管参数化详情和离开页面后的 TTL 缓存；
// - StreamProvider.family 管某一订单的实时状态并自动取消订阅。
//
// 建议阅读顺序：Repository Provider -> Filter Notifier -> OrderFeedState
// -> OrderFeedNotifier.build/loadMore/create/cancel -> 派生列表 -> 详情/实时 Provider。

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/localization/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/logger.dart';
import '../../auth/auth.dart';
import '../model/order.dart';
import '../repository/order_repository.dart';

/// Repository 依赖注入入口。
///
/// ViewModel 只依赖接口；单元测试通过 override 注入 Fake，接入真实后端时则在
/// 这里换成 ApiOrderRepository。业务代码不需要 locator 或全局单例。
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  // Repository 缓存按登录用户隔离。user id 改变时创建新实例，orderFeedProvider
  // 因为 watch 了本 Provider 也会重建，避免退出后把上一位用户的订单留给新用户。
  ref.watch(currentUserIdProvider);
  return MockOrderRepository();
});

enum OrderFilter { all, active, finished }

/// 简单、同步且有修改命令的状态使用 Notifier，而不是 AsyncNotifier。
class OrderFilterNotifier extends Notifier<OrderFilter> {
  @override
  OrderFilter build() {
    ref.watch(currentUserIdProvider);
    return OrderFilter.all;
  }

  void change(OrderFilter filter) => state = filter;
}

// 筛选和订单列表都属于根 Tab 状态。Riverpod 3 会暂停 TickerMode 关闭区域里的
// Consumer 订阅；这里不使用 autoDispose，保证切换 Tab 后仍保留筛选和已加载页。
final orderFilterProvider = NotifierProvider<OrderFilterNotifier, OrderFilter>(
  OrderFilterNotifier.new,
);

/// 一次性操作结果只通知 View 展示 SnackBar。
///
/// 初次加载失败由 AsyncError 表达；分页、创建和取消失败则保留已有列表，用这个
/// 轻量结果通知 UI。两类错误分开后，单条命令失败不会把整个页面切回错误页。
class OrderOperationResult {
  const OrderOperationResult.success(this.message) : isError = false;
  const OrderOperationResult.failure(this.message) : isError = true;

  /// View 可直接展示的消息，不携带 BuildContext 或 SnackBar 类型。
  final String message;
  final bool isError;
}

/// 订单列表的不可变页面状态。
///
/// 构造时冻结 List/Set/Map，防止 View 或异步命令意外原地修改旧状态。
class OrderFeedState {
  OrderFeedState({
    List<Order> orders = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isCreating = false,
    Set<String> updatingIds = const {},
    Map<String, OrderStatus> pendingRemoteStatuses = const {},
    this.operationResult,
  }) : orders = List.unmodifiable(orders),
       updatingIds = Set.unmodifiable(updatingIds),
       pendingRemoteStatuses = Map.unmodifiable(pendingRemoteStatuses);

  OrderFeedState._({
    required this.orders,
    required this.page,
    required this.hasMore,
    required this.isLoadingMore,
    required this.isCreating,
    required this.updatingIds,
    required this.pendingRemoteStatuses,
    required this.operationResult,
  });

  /// 当前已合并、按 id 去重的订单集合。
  final List<Order> orders;

  /// 已成功加载的最后页码及服务端是否还有下一页。
  final int page;
  final bool hasMore;

  /// 局部命令状态。它们不应把整个 AsyncValue 改成 AsyncLoading。
  final bool isLoadingMore;
  final bool isCreating;

  /// 正在乐观更新的订单 id；View 只给对应卡片显示 loading。
  final Set<String> updatingIds;

  /// 乐观命令期间到达的实时状态，失败回滚时合并而不是丢弃。
  final Map<String, OrderStatus> pendingRemoteStatuses;

  /// 供 ref.listen 消费的一次性操作结果。
  final OrderOperationResult? operationResult;

  OrderFeedState copyWith({
    List<Order>? orders,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isCreating,
    Set<String>? updatingIds,
    Map<String, OrderStatus>? pendingRemoteStatuses,
    OrderOperationResult? operationResult,
    bool clearOperationResult = false,
  }) {
    return OrderFeedState._(
      // 未修改的集合直接复用不可变实例，使 select 能过滤纯 loading/event 变化。
      orders: orders == null ? this.orders : List.unmodifiable(orders),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isCreating: isCreating ?? this.isCreating,
      updatingIds: updatingIds == null
          ? this.updatingIds
          : Set.unmodifiable(updatingIds),
      pendingRemoteStatuses: pendingRemoteStatuses == null
          ? this.pendingRemoteStatuses
          : Map.unmodifiable(pendingRemoteStatuses),
      operationResult: clearOperationResult
          ? null
          : operationResult ?? this.operationResult,
    );
  }
}

class OrderFeedNotifier extends AsyncNotifier<OrderFeedState> {
  // 同一个列表 Provider 可能同时执行分页、创建和取消，因此跟踪全部请求令牌。
  final Set<CancelToken> _activeRequestTokens = {};

  // 命令方法用 read 获取当前 Repository，不额外建立重复依赖。
  OrderRepository get _repository => ref.read(orderRepositoryProvider);

  @override
  Future<OrderFeedState> build() async {
    // watch 建立依赖关系：Repository Provider 被 invalidate/override 时，
    // Riverpod 会自动重建订单列表，不会出现“列表来自旧仓库、命令发给新仓库”。
    final repository = ref.watch(orderRepositoryProvider);
    // Provider 因路由、容器或登录用户变化销毁时，统一取消全部未完成请求。
    ref.onDispose(_cancelActiveRequests);
    final cancelToken = _startRequest();
    try {
      final firstPage = await repository.fetchOrders(
        page: 1,
        cancelToken: cancelToken,
      );
      return OrderFeedState(
        orders: firstPage.orders,
        hasMore: firstPage.hasMore,
      );
    } catch (error) {
      if (!_isCancellation(error)) {
        AppLogger.log('Order initial load failed: $error');
      }
      rethrow;
    } finally {
      _finishRequest(cancelToken);
    }
  }

  /// 加载下一页时保留当前列表，只更新底部 loading。
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    final nextPage = current.page + 1;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearOperationResult: true),
    );

    final repository = _repository;
    final cancelToken = _startRequest();
    try {
      final result = await repository.fetchOrders(
        page: nextPage,
        cancelToken: cancelToken,
      );
      if (!ref.mounted || !identical(repository, _repository)) return;

      // await 之后必须读取 latest，不能用 await 之前的 current 覆盖整个 state。
      // 否则分页与创建/取消并发时，后返回的旧快照会吞掉先完成的修改。
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          // Mock 使用 offset 分页；创建订单会移动 offset，按 id 合并避免重复。
          // 真实订单接口更推荐 cursor 分页。
          orders: _mergeUnique(latest.orders, result.orders),
          page: nextPage,
          hasMore: result.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      if (!ref.mounted || !identical(repository, _repository)) return;
      if (_isCancellation(error)) return;
      AppLogger.log('Order pagination failed: $error');
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          isLoadingMore: false,
          operationResult: const OrderOperationResult.failure(
            AppStrings.orderLoadMoreFailed,
          ),
        ),
      );
    } finally {
      _finishRequest(cancelToken);
    }
  }

  /// 创建订单也是局部命令，不让已有订单列表闪成全屏 loading。
  Future<void> createOrder() async {
    final current = state.value;
    if (current == null || current.isCreating) return;

    state = AsyncData(
      current.copyWith(isCreating: true, clearOperationResult: true),
    );

    final repository = _repository;
    final cancelToken = _startRequest();
    try {
      final created = await repository.createOrder(cancelToken: cancelToken);
      if (!ref.mounted || !identical(repository, _repository)) return;
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          orders: [
            created,
            ...latest.orders.where((order) => order.id != created.id),
          ],
          isCreating: false,
          operationResult: const OrderOperationResult.success(
            AppStrings.orderCreated,
          ),
        ),
      );
    } catch (error) {
      if (!ref.mounted || !identical(repository, _repository)) return;
      if (_isCancellation(error)) return;
      AppLogger.log('Order creation failed: $error');
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          isCreating: false,
          operationResult: const OrderOperationResult.failure(
            AppStrings.orderCreateFailed,
          ),
        ),
      );
    } finally {
      _finishRequest(cancelToken);
    }
  }

  /// 先把目标订单改成已取消，让操作即时反馈；接口失败时恢复 oldOrder。
  Future<void> cancelOrder(String id) async {
    final current = state.value;
    if (current == null || current.updatingIds.contains(id)) return;

    final index = current.orders.indexWhere((order) => order.id == id);
    if (index == -1) {
      state = AsyncData(
        current.copyWith(
          operationResult: OrderOperationResult.failure(
            AppStrings.orderMissing(id),
          ),
        ),
      );
      return;
    }

    final oldOrder = current.orders[index];
    if (!oldOrder.canCancel) return;

    state = AsyncData(
      current.copyWith(
        orders: _replaceOrder(
          current.orders,
          oldOrder.copyWith(status: OrderStatus.cancelled),
        ),
        updatingIds: {...current.updatingIds, id},
        pendingRemoteStatuses: {...current.pendingRemoteStatuses}..remove(id),
        clearOperationResult: true,
      ),
    );

    final repository = _repository;
    final cancelToken = _startRequest();
    try {
      final updated = await repository.cancelOrder(
        id,
        cancelToken: cancelToken,
      );
      if (!ref.mounted || !identical(repository, _repository)) return;
      final latest = state.value;
      if (latest == null) return;
      final pendingRemoteStatuses = {...latest.pendingRemoteStatuses}
        ..remove(id);

      state = AsyncData(
        latest.copyWith(
          orders: _replaceOrder(latest.orders, updated),
          updatingIds: {...latest.updatingIds}..remove(id),
          pendingRemoteStatuses: pendingRemoteStatuses,
          operationResult: const OrderOperationResult.success(
            AppStrings.orderCancelled,
          ),
        ),
      );

      // 命令改变了服务端实体，主动让同一 id 的详情和实时状态失效。
      ref.invalidate(orderDetailProvider(id));
      ref.invalidate(orderStatusProvider(id));
    } catch (error) {
      if (!ref.mounted || !identical(repository, _repository)) return;
      if (_isCancellation(error)) return;
      AppLogger.log('Order cancellation failed: $error');
      final latest = state.value;
      if (latest == null) return;
      final remoteStatus = latest.pendingRemoteStatuses[id];
      final rollbackOrder = remoteStatus == null
          ? oldOrder
          : oldOrder.copyWith(status: remoteStatus);
      final pendingRemoteStatuses = {...latest.pendingRemoteStatuses}
        ..remove(id);

      state = AsyncData(
        latest.copyWith(
          // 若取消期间收到物流推送，回滚到最新远端状态，而不是旧快照。
          orders: _replaceOrder(latest.orders, rollbackOrder),
          updatingIds: {...latest.updatingIds}..remove(id),
          pendingRemoteStatuses: pendingRemoteStatuses,
          operationResult: const OrderOperationResult.failure(
            AppStrings.orderCancelRolledBack,
          ),
        ),
      );
    } finally {
      _finishRequest(cancelToken);
    }
  }

  /// 把详情页收到的 WebSocket/SSE 状态同步回列表。
  void applyRemoteStatus(String id, OrderStatus status) {
    final current = state.value;
    if (current == null) return;
    final index = current.orders.indexWhere((order) => order.id == id);
    if (index == -1) return;

    // 本地乐观命令进行中时不直接覆盖 UI，但也不能丢掉远端事件；暂存每个 id
    // 的最新状态，命令成功时清理，失败回滚时合并。
    if (current.updatingIds.contains(id)) {
      state = AsyncData(
        current.copyWith(
          pendingRemoteStatuses: {...current.pendingRemoteStatuses, id: status},
        ),
      );
      return;
    }
    if (current.orders[index].status == status) return;

    state = AsyncData(
      current.copyWith(
        orders: _replaceOrder(
          current.orders,
          current.orders[index].copyWith(status: status),
        ),
      ),
    );
  }

  /// SnackBar 展示后清掉一次性结果，避免 Widget 重建时重复提示。
  void consumeOperationResult() {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(clearOperationResult: true));
    }
  }

  CancelToken _startRequest() {
    // 每个并发命令有独立令牌，完成后只移除自己的令牌。
    final cancelToken = CancelToken();
    _activeRequestTokens.add(cancelToken);
    return cancelToken;
  }

  void _finishRequest(CancelToken cancelToken) {
    // 已完成请求不再需要 dispose 阶段重复取消。
    _activeRequestTokens.remove(cancelToken);
  }

  void _cancelActiveRequests() {
    // toList 创建快照，避免遍历时集合被异步 finally 修改。
    for (final cancelToken in _activeRequestTokens.toList()) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('order provider disposed or session changed');
      }
    }
    _activeRequestTokens.clear();
  }

  List<Order> _mergeUnique(List<Order> current, List<Order> incoming) {
    // 创建订单会移动 offset；以 id 去重可防止后续页重复追加已有订单。
    final knownIds = current.map((order) => order.id).toSet();
    return [...current, ...incoming.where((order) => knownIds.add(order.id))];
  }

  List<Order> _replaceOrder(List<Order> orders, Order replacement) {
    return orders
        .map((order) => order.id == replacement.id ? replacement : order)
        .toList(growable: false);
  }
}

bool _isCancellation(Object error) {
  return (error is DioException && CancelToken.isCancel(error)) ||
      (error is ApiException && error.isCancelled);
}

/// 只重试可能自行恢复的网络错误；参数、权限和业务异常直接交给 UI。
bool _isTransientOrderError(Object error) {
  if (error is BusinessException) return false;
  if (error is ApiException) {
    return error.code == ApiException.networkError ||
        error.code == ApiException.timeoutError ||
        error.code == ApiException.serverError ||
        (error.code >= 500 && error.code < 600);
  }
  if (error is! DioException || CancelToken.isCancel(error)) return false;
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.badResponse => (error.response?.statusCode ?? 0) >= 500,
    DioExceptionType.cancel ||
    DioExceptionType.badCertificate ||
    DioExceptionType.unknown => false,
  };
}

// 根 Tab 要跨 Tab 保留已加载分页，所以不使用 autoDispose。
// retry 是 Riverpod 3 的统一 Provider 重试能力：仅初载最多重试两次；
// 分页、创建和取消错误已在命令内部处理，不会触发 Provider 重建重试。
final orderFeedProvider =
    AsyncNotifierProvider<OrderFeedNotifier, OrderFeedState>(
      OrderFeedNotifier.new,
      retry: (retryCount, error) {
        if (retryCount >= 2 || !_isTransientOrderError(error)) return null;
        return Duration(milliseconds: 400 * (retryCount + 1));
      },
    );

/// 派生状态没有修改方法，也不复制保存到 OrderFeedState。
final visibleOrdersProvider = Provider.autoDispose<List<Order>>((ref) {
  // 只订阅 orders 列表；分页按钮 loading、一次性提示等字段变化不重新筛选列表。
  final orders = ref.watch(
    orderFeedProvider.select(
      (asyncState) => asyncState.value?.orders ?? const <Order>[],
    ),
  );
  final filter = ref.watch(orderFilterProvider);
  return switch (filter) {
    OrderFilter.all => orders,
    OrderFilter.active => orders.where((order) => order.isActive).toList(),
    OrderFilter.finished => orders.where((order) => !order.isActive).toList(),
  };
});

/// 详情成功后的缓存时长单独注入，测试可以缩短 TTL 而不用真实等待 30 秒。
final orderDetailCacheDurationProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 30);
});

/// 每个订单 id 都有独立缓存；成功后，最后一个监听离开再保留指定 TTL。
/// 未完成的请求不 keepAlive，弹窗关闭时会立即通过 CancelToken 中止。
final orderDetailProvider = FutureProvider.autoDispose.family<Order, String>((
  ref,
  id,
) async {
  final repository = ref.watch(orderRepositoryProvider);
  final cacheDuration = ref.watch(orderDetailCacheDurationProvider);
  final cancelToken = CancelToken();
  void Function()? closeCache;
  Timer? cacheTimer;
  var hasActiveListener = true;
  var requestCompleted = false;

  // 请求阶段离开：立即取消；成功缓存阶段离开：开始 TTL。
  ref.onCancel(() {
    hasActiveListener = false;
    if (!requestCompleted) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('order detail listener removed');
      }
      return;
    }
    cacheTimer?.cancel();
    cacheTimer = Timer(cacheDuration, () => closeCache?.call());
  });
  ref.onResume(() {
    hasActiveListener = true;
    cacheTimer?.cancel();
    cacheTimer = null;
  });
  ref.onDispose(() {
    cacheTimer?.cancel();
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('order detail provider disposed');
    }
  });

  try {
    final order = await repository.fetchOrder(id, cancelToken: cancelToken);
    requestCompleted = true;
    if (!ref.mounted || !hasActiveListener) return order;

    // 只有成功且仍有人监听时才缓存；错误和已离开的请求都不保活。
    final cacheLink = ref.keepAlive();
    closeCache = cacheLink.close;
    return order;
  } catch (error) {
    if (!_isCancellation(error)) {
      AppLogger.log('Order detail load failed: $error');
    }
    rethrow;
  }
});

/// StreamProvider 负责订阅、AsyncValue 转换以及 autoDispose 时取消 Stream。
/// map 中把后端推送同步给列表；read 只发送命令，不建立反向依赖，避免循环刷新。
final orderStatusProvider = StreamProvider.autoDispose
    .family<OrderStatus, String>((ref, id) {
      return ref.watch(orderRepositoryProvider).watchOrderStatus(id).map((
        status,
      ) {
        ref.read(orderFeedProvider.notifier).applyRemoteStatus(id, status);
        return status;
      });
    });
