// lib/features/orders/repository/order_repository.dart
//
// Repository 模拟真实订单后端：分页查询、详情、创建、取消和物流状态流。
// ViewModel 不知道这些数据是内存模拟；接真实 API 时只替换实现。

import 'dart:async';

import 'package:dio/dio.dart';

import '../model/order.dart';

abstract interface class OrderRepository {
  Future<OrderPageResult> fetchOrders({
    required int page,
    int pageSize = 3,
    CancelToken? cancelToken,
  });
  Future<Order> fetchOrder(String id, {CancelToken? cancelToken});
  Future<Order> createOrder({CancelToken? cancelToken});
  Future<Order> cancelOrder(String id, {CancelToken? cancelToken});
  Stream<OrderStatus> watchOrderStatus(String id);
}

class MockOrderRepository implements OrderRepository {
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
    CancelToken? cancelToken,
  }) async {
    await _simulateLatency(const Duration(milliseconds: 500), cancelToken);
    final start = (page - 1) * pageSize;
    if (start >= _orders.length) {
      return const OrderPageResult(orders: [], hasMore: false);
    }
    final end = (start + pageSize).clamp(0, _orders.length);
    return OrderPageResult(
      orders: List.unmodifiable(_orders.sublist(start, end)),
      hasMore: end < _orders.length,
    );
  }

  @override
  Future<Order> fetchOrder(String id, {CancelToken? cancelToken}) async {
    await _simulateLatency(const Duration(milliseconds: 280), cancelToken);
    return _findOrder(id);
  }

  @override
  Future<Order> createOrder({CancelToken? cancelToken}) async {
    await _simulateLatency(const Duration(milliseconds: 450), cancelToken);
    final order = Order(
      id: 'order-${DateTime.now().microsecondsSinceEpoch}',
      title: '新建演示订单',
      totalAmount: 1888,
      status: OrderStatus.pendingPayment,
      createdAt: DateTime.now(),
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<Order> cancelOrder(String id, {CancelToken? cancelToken}) async {
    await _simulateLatency(const Duration(milliseconds: 400), cancelToken);
    final index = _findOrderIndex(id);
    final oldOrder = _orders[index];
    if (!oldOrder.canCancel) {
      throw StateError('当前订单状态不允许取消');
    }
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
    final index = _orders.indexWhere((order) => order.id == id);
    if (index == -1) throw StateError('订单不存在：$id');
    return index;
  }

  Order _findOrder(String id) => _orders[_findOrderIndex(id)];

  /// 让 Mock 延迟也遵守与 Dio 相同的取消语义，生命周期测试无需依赖真实网络。
  Future<void> _simulateLatency(
    Duration duration,
    CancelToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      await Future<void>.delayed(duration);
      return;
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;

    await Future.any<void>([
      Future<void>.delayed(duration),
      cancelToken.whenCancel.then<void>((error) => throw error),
    ]);
  }
}
