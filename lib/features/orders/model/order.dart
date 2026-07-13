// lib/features/orders/model/order.dart
//
// 订单领域模型。状态变化通过 copyWith 生成新对象，便于 Riverpod 使用 ==/identity
// 判断通知，也让乐观更新失败时能够保留旧对象并回滚。

enum OrderStatus { pendingPayment, processing, shipped, delivered, cancelled }

class Order {
  const Order({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;

  bool get isActive => switch (status) {
    OrderStatus.pendingPayment ||
    OrderStatus.processing ||
    OrderStatus.shipped => true,
    OrderStatus.delivered || OrderStatus.cancelled => false,
  };

  /// 只有服务端允许撤销的状态才显示取消入口。
  /// “进行中”和“可取消”是两个不同的业务概念：已发货仍在进行中，但不可取消。
  bool get canCancel => switch (status) {
    OrderStatus.pendingPayment || OrderStatus.processing => true,
    OrderStatus.shipped ||
    OrderStatus.delivered ||
    OrderStatus.cancelled => false,
  };

  Order copyWith({OrderStatus? status}) {
    return Order(
      id: id,
      title: title,
      totalAmount: totalAmount,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class OrderPageResult {
  const OrderPageResult({required this.orders, required this.hasMore});
  final List<Order> orders;
  final bool hasMore;
}
