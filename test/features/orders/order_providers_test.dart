import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/shared/localization/app_strings.dart';
import 'package:riverpod_mvvm/features/orders/model/order.dart';
import 'package:riverpod_mvvm/features/orders/repository/order_repository.dart';
import 'package:riverpod_mvvm/features/orders/view_model/order_view_model.dart';

class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({
    this.cancelCompleter,
    this.pageTwoCompleter,
    this.detailCompleter,
    this.statusController,
  });

  /// 非 null Completer 让测试决定请求何时成功或失败。
  final Completer<Order>? cancelCompleter;
  final Completer<OrderPageResult>? pageTwoCompleter;
  final Completer<Order>? detailCompleter;
  final StreamController<OrderStatus>? statusController;
  final Map<String, int> detailRequestCount = {};
  final Completer<CancelToken> detailRequestStarted = Completer<CancelToken>();

  final List<Order> _orders = [
    Order(
      id: 'active-1',
      title: '待处理订单',
      totalAmount: 100,
      status: OrderStatus.processing,
      createdAt: DateTime(2026, 7, 1),
    ),
    Order(
      id: 'finished-1',
      title: '已完成订单',
      totalAmount: 200,
      status: OrderStatus.delivered,
      createdAt: DateTime(2026, 7, 2),
    ),
    Order(
      id: 'active-2',
      title: '待付款订单',
      totalAmount: 300,
      status: OrderStatus.pendingPayment,
      createdAt: DateTime(2026, 7, 3),
    ),
  ];

  @override
  Future<OrderPageResult> fetchOrders({
    required int page,
    int pageSize = 3,
    CancelToken? cancelToken,
  }) async {
    // 固定分成两页，让测试不依赖生产 Repository 的分页算法。
    if (page == 1) {
      return OrderPageResult(orders: _orders.take(2).toList(), hasMore: true);
    }
    if (pageTwoCompleter case final completer?) {
      return completer.future;
    }
    return OrderPageResult(orders: _orders.skip(2).toList(), hasMore: false);
  }

  @override
  Future<Order> createOrder({CancelToken? cancelToken}) async {
    final created = Order(
      id: 'created-1',
      title: '新建订单',
      totalAmount: 888,
      status: OrderStatus.pendingPayment,
      createdAt: DateTime(2026, 7, 4),
    );
    _orders.insert(0, created);
    return created;
  }

  @override
  Future<Order> cancelOrder(String id, {CancelToken? cancelToken}) async {
    if (cancelCompleter case final completer?) {
      return completer.future;
    }

    final index = _orders.indexWhere((order) => order.id == id);
    final updated = _orders[index].copyWith(status: OrderStatus.cancelled);
    _orders[index] = updated;
    return updated;
  }

  @override
  Future<Order> fetchOrder(String id, {CancelToken? cancelToken}) async {
    detailRequestCount.update(id, (count) => count + 1, ifAbsent: () => 1);
    if (detailCompleter case final completer?) {
      if (!detailRequestStarted.isCompleted) {
        detailRequestStarted.complete(cancelToken!);
      }
      return completer.future;
    }
    return _orders.firstWhere((order) => order.id == id);
  }

  @override
  Stream<OrderStatus> watchOrderStatus(String id) {
    if (statusController case final controller?) return controller.stream;
    final order = _orders.firstWhere((item) => item.id == id);
    return Stream.value(order.status);
  }
}

ProviderContainer _createContainer(
  _FakeOrderRepository repository, {
  Duration? detailCacheDuration,
}) {
  // 所有测试复用同一 override 入口；TTL 可缩短到毫秒，避免真实等待 30 秒。
  return ProviderContainer(
    overrides: [
      orderRepositoryProvider.overrideWith((ref) => repository),
      if (detailCacheDuration != null)
        orderDetailCacheDurationProvider.overrideWithValue(detailCacheDuration),
    ],
  );
}

void main() {
  test('订单列表在初始加载后可分页，创建时保留已有数据', () async {
    final repository = _FakeOrderRepository();
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    // listen 模拟页面的 ref.watch，也能记录整个异步状态生命周期。
    final subscription = container.listen(orderFeedProvider, (_, _) {});
    addTearDown(subscription.close);

    final firstPage = await container.read(orderFeedProvider.future);
    expect(firstPage.orders.map((order) => order.id), [
      'active-1',
      'finished-1',
    ]);
    expect(firstPage.hasMore, isTrue);

    await container.read(orderFeedProvider.notifier).loadMore();
    final afterLoadMore = container.read(orderFeedProvider).requireValue;
    expect(afterLoadMore.orders, hasLength(3));
    expect(afterLoadMore.page, 2);
    expect(afterLoadMore.hasMore, isFalse);

    await container.read(orderFeedProvider.notifier).createOrder();
    final afterCreate = container.read(orderFeedProvider).requireValue;
    expect(afterCreate.orders, hasLength(4));
    expect(afterCreate.orders.first.id, 'created-1');
    expect(afterCreate.operationResult?.message, AppStrings.orderCreated);
    expect(afterCreate.operationResult?.isError, isFalse);

    // 消费 SnackBar 事件只改变 operationResult，应复用不可变订单集合。
    // 这样 visibleOrdersProvider 的 select 不会触发无意义的筛选重算。
    final ordersBeforeConsume = afterCreate.orders;
    container.read(orderFeedProvider.notifier).consumeOperationResult();
    final afterConsume = container.read(orderFeedProvider).requireValue;
    expect(afterConsume.operationResult, isNull);
    expect(identical(afterConsume.orders, ordersBeforeConsume), isTrue);
  });

  test('取消订单先乐观更新，请求失败后回滚原状态', () async {
    final cancelCompleter = Completer<Order>();
    final repository = _FakeOrderRepository(cancelCompleter: cancelCompleter);
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    final subscription = container.listen(orderFeedProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(orderFeedProvider.future);

    final cancelFuture = container
        .read(orderFeedProvider.notifier)
        .cancelOrder('active-1');

    // Repository Future 还未完成，但 UI 状态已立即改成 cancelled。
    final optimistic = container.read(orderFeedProvider).requireValue;
    expect(optimistic.orders.first.status, OrderStatus.cancelled);
    expect(optimistic.updatingIds, contains('active-1'));

    cancelCompleter.completeError(StateError('服务端拒绝取消'));
    await cancelFuture;

    final rolledBack = container.read(orderFeedProvider).requireValue;
    expect(rolledBack.orders.first.status, OrderStatus.processing);
    expect(rolledBack.updatingIds, isEmpty);
    expect(
      rolledBack.operationResult?.message,
      AppStrings.orderCancelRolledBack,
    );
    expect(rolledBack.operationResult?.isError, isTrue);
  });

  test('取消期间收到实时状态且请求失败时回滚到最新远端状态', () async {
    final cancelCompleter = Completer<Order>();
    final statusController = StreamController<OrderStatus>.broadcast();
    addTearDown(statusController.close);
    final repository = _FakeOrderRepository(
      cancelCompleter: cancelCompleter,
      statusController: statusController,
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    final feedSubscription = container.listen(orderFeedProvider, (_, _) {});
    addTearDown(feedSubscription.close);
    await container.read(orderFeedProvider.future);

    final statusSubscription = container.listen(
      orderStatusProvider('active-1'),
      (_, _) {},
    );
    addTearDown(statusSubscription.close);
    await Future<void>.delayed(Duration.zero);

    final cancelFuture = container
        .read(orderFeedProvider.notifier)
        .cancelOrder('active-1');
    statusController.add(OrderStatus.shipped);
    await Future<void>.delayed(Duration.zero);

    expect(
      container
          .read(orderFeedProvider)
          .requireValue
          .pendingRemoteStatuses['active-1'],
      OrderStatus.shipped,
    );

    cancelCompleter.completeError(StateError('服务端拒绝取消'));
    await cancelFuture;

    final rolledBack = container.read(orderFeedProvider).requireValue;
    expect(rolledBack.orders.first.status, OrderStatus.shipped);
    expect(rolledBack.pendingRemoteStatuses, isEmpty);
  });

  test('分页与创建并发完成时基于最新状态合并且按 id 去重', () async {
    final pageTwoCompleter = Completer<OrderPageResult>();
    final repository = _FakeOrderRepository(pageTwoCompleter: pageTwoCompleter);
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    final subscription = container.listen(orderFeedProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(orderFeedProvider.future);

    final loadMoreFuture = container
        .read(orderFeedProvider.notifier)
        .loadMore();
    expect(
      container.read(orderFeedProvider).requireValue.isLoadingMore,
      isTrue,
    );

    // 分页请求尚未返回时创建订单，模拟两个真实接口并发。
    await container.read(orderFeedProvider.notifier).createOrder();
    pageTwoCompleter.complete(
      OrderPageResult(
        // finished-1 是 offset 移动后可能重复出现的数据。
        orders: [
          repository._orders.firstWhere((order) => order.id == 'finished-1'),
          repository._orders.firstWhere((order) => order.id == 'active-2'),
        ],
        hasMore: false,
      ),
    );
    await loadMoreFuture;

    final state = container.read(orderFeedProvider).requireValue;
    final ids = state.orders.map((order) => order.id).toList();
    expect(ids, ['created-1', 'active-1', 'finished-1', 'active-2']);
    expect(ids.toSet(), hasLength(ids.length));
    expect(state.isCreating, isFalse);
    expect(state.isLoadingMore, isFalse);
  });

  test('FutureProvider.family 按订单 id 隔离详情状态', () async {
    final repository = _FakeOrderRepository();
    final container = _createContainer(
      repository,
      detailCacheDuration: const Duration(milliseconds: 5),
    );
    addTearDown(container.dispose);

    final activeProvider = orderDetailProvider('active-1');
    final activeSubscription = container.listen(activeProvider, (_, _) {});
    final active = await container.read(activeProvider.future);
    activeSubscription.close();
    final finished = await container.read(
      orderDetailProvider('finished-1').future,
    );

    expect(active.id, 'active-1');
    expect(finished.id, 'finished-1');
    expect(repository.detailRequestCount, {'active-1': 1, 'finished-1': 1});

    // 测试把默认 30 秒 TTL override 为 5ms；到期前会复用同一 family 缓存。
    final cached = await container.read(orderDetailProvider('active-1').future);
    expect(cached.id, active.id);
    expect(repository.detailRequestCount['active-1'], 1);

    await Future<void>.delayed(const Duration(milliseconds: 15));
    await container.pump();
    await container.read(orderDetailProvider('active-1').future);
    expect(repository.detailRequestCount['active-1'], 2);
  });

  test('详情请求未完成时最后一个监听离开会取消 CancelToken', () async {
    final repository = _FakeOrderRepository(
      detailCompleter: Completer<Order>(),
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    final subscription = container.listen(
      orderDetailProvider('active-1'),
      (_, _) {},
    );
    final cancelToken = await repository.detailRequestStarted.future;

    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(cancelToken.isCancelled, isTrue);
  });

  test('StreamProvider.family 销毁时取消底层实时订阅', () async {
    final streamSubscribed = Completer<void>();
    final streamCancelled = Completer<void>();
    final statusController = StreamController<OrderStatus>.broadcast(
      onListen: streamSubscribed.complete,
      onCancel: streamCancelled.complete,
    );
    addTearDown(statusController.close);
    final repository = _FakeOrderRepository(statusController: statusController);
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    final subscription = container.listen(
      orderStatusProvider('active-1'),
      (_, _) {},
    );
    await streamSubscribed.future;

    subscription.close();
    await streamCancelled.future.timeout(const Duration(seconds: 1));
  });
}

// 订单 Provider 综合测试：Fake Repository 可精确控制 Future/Stream 完成时机，
// 用于复现分页与创建并发、乐观取消与远端事件竞态、TTL 和 CancelToken 生命周期。
