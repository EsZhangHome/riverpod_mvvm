// lib/features/orders/repository/order_repository.dart
//
// Repository 模拟真实订单后端：分页查询、详情、创建、取消和物流状态流。
// ViewModel 不知道这些数据是内存模拟；接真实 API 时只替换实现。
//
// 调用链：OrderFeedNotifier -> OrderRepository -> Future/Stream -> State。
// 所有 Future 都接收底座取消令牌，使 Mock 和真实网络请求具有一致取消语义。

import 'dart:async';

import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import '../model/order.dart';

abstract interface class OrderRepository {
  /// 获取指定页；列表初载和加载更多复用同一个接口。
  Future<OrderPageResult> fetchOrders({
    required int page,
    int pageSize = 3,
    RequestCancellationToken? cancelToken,
  });

  /// family 详情 Provider 按 id 调用。
  Future<Order> fetchOrder(String id, {RequestCancellationToken? cancelToken});

  /// 创建和取消是局部命令，完成后返回服务端最终实体。
  Future<Order> createOrder({RequestCancellationToken? cancelToken});
  Future<Order> cancelOrder(String id, {RequestCancellationToken? cancelToken});

  /// 连续状态使用 Stream，而不是反复轮询 FutureProvider。
  Stream<OrderStatus> watchOrderStatus(String id);
}

/// 完全在内存中运行的可变后端替身。
class MockOrderRepository implements OrderRepository {
  // Repository 持有“服务端数据”；ViewModel 只能通过接口读取或修改。
  final List<Order> _orders = List.generate(8, (index) {
    final statuses = OrderStatus.values;
    return Order(
      id: 'order-${index + 1}',
      title: '数码商品订单 #${1001 + index}',
      totalAmount: 299 + index * 430,
      status: statuses[index % statuses.length],
      createdAt: DateTime.now().subtract(Duration(days: index)),
    );
  });

  @override
  Future<OrderPageResult> fetchOrders({
    required int page,
    int pageSize = 3,
    RequestCancellationToken? cancelToken,
  }) async {
    // 步骤 1：先模拟可取消的网络等待。
    await _simulateLatency(const Duration(milliseconds: 500), cancelToken);
    // 步骤 2：由页码和 pageSize 计算左闭右开区间。
    final start = (page - 1) * pageSize;
    if (start >= _orders.length) {
      return const OrderPageResult(orders: [], hasMore: false);
    }
    final end = (start + pageSize).clamp(0, _orders.length);
    // 步骤 3：冻结返回列表，防止调用方修改 Repository 内存数据。
    return OrderPageResult(
      orders: List.unmodifiable(_orders.sublist(start, end)),
      hasMore: end < _orders.length,
    );
  }

  @override
  Future<Order> fetchOrder(
    String id, {
    RequestCancellationToken? cancelToken,
  }) async {
    await _simulateLatency(const Duration(milliseconds: 280), cancelToken);
    return _findOrder(id);
  }

  @override
  Future<Order> createOrder({RequestCancellationToken? cancelToken}) async {
    await _simulateLatency(const Duration(milliseconds: 450), cancelToken);
    // 模拟服务端生成 id、默认状态和创建时间。
    final order = Order(
      id: 'order-${DateTime.now().microsecondsSinceEpoch}',
      title: '新建演示订单',
      totalAmount: 1888,
      status: OrderStatus.pendingPayment,
      createdAt: DateTime.now(),
    );
    // 新订单插到服务端列表首位，后续刷新也能读取到。
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<Order> cancelOrder(
    String id, {
    RequestCancellationToken? cancelToken,
  }) async {
    await _simulateLatency(const Duration(milliseconds: 400), cancelToken);
    // 先查最新服务端对象，不能相信客户端传来的旧状态。
    final index = _findOrderIndex(id);
    final oldOrder = _orders[index];
    if (!oldOrder.canCancel) {
      throw StateError('当前订单状态不允许取消');
    }
    // 创建新 Order 替换旧对象，保持不可变实体语义。
    final updated = oldOrder.copyWith(status: OrderStatus.cancelled);
    _orders[index] = updated;
    return updated;
  }

  @override
  Stream<OrderStatus> watchOrderStatus(String id) async* {
    // 真实项目通常来自独立运行的 WebSocket/SSE 服务端。Mock 为保证测试和演示
    // 可预测，只在客户端订阅后先发送当前值，再模拟一次状态推进。
    final order = _findOrder(id);
    yield order.status;
    if (order.status == OrderStatus.processing) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final current = _findOrder(id);
      if (current.status != OrderStatus.processing) return;
      final updated = current.copyWith(status: OrderStatus.shipped);
      _orders[_findOrderIndex(id)] = updated;
      yield updated.status;
    } else if (order.status == OrderStatus.shipped) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final current = _findOrder(id);
      if (current.status != OrderStatus.shipped) return;
      final updated = current.copyWith(status: OrderStatus.delivered);
      _orders[_findOrderIndex(id)] = updated;
      yield updated.status;
    }
  }

  int _findOrderIndex(String id) {
    // Repository 统一把“不存在”转换为明确业务异常。
    final index = _orders.indexWhere((order) => order.id == id);
    if (index == -1) throw StateError('订单不存在：$id');
    return index;
  }

  Order _findOrder(String id) => _orders[_findOrderIndex(id)];

  /// 让 Mock 延迟也遵守与真实网络相同的取消语义，生命周期测试无需依赖 Dio。
  Future<void> _simulateLatency(
    Duration duration,
    RequestCancellationToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      // 没有令牌时退化为普通延迟，便于独立调用 Repository。
      await Future<void>.delayed(duration);
      return;
    }
    if (cancelToken.isCancelled) {
      throw RequestCancellationFailure(cancelToken.reason);
    }

    // 延迟完成与取消事件竞争；谁先完成就决定 Future 结果。
    await Future.any<void>([
      Future<void>.delayed(duration),
      cancelToken.whenCancelled.then<void>((_) {}),
    ]);

    // Future.any 可能由取消信号完成。显式检查可阻止 Mock 在取消后继续修改数据，
    // 同时不需要伪造某个具体网络库的异常类型。
    if (cancelToken.isCancelled) {
      throw RequestCancellationFailure(cancelToken.reason);
    }
  }
}
