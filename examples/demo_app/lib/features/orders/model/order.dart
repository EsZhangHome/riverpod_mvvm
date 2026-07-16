// lib/features/orders/model/order.dart
//
// 订单领域模型。状态变化通过 copyWith 生成新对象，让 Riverpod 能通过新引用可靠
// 通知消费者，也让乐观更新失败时能够保留旧对象并回滚。
//
// 状态推进示例：pendingPayment -> processing -> shipped -> delivered；
// cancelled 是终止状态。Model 只表达规则，不执行网络请求或 UI 提示。

/// 订单生命周期状态。枚举值由 View 转成本地化文案。
enum OrderStatus { pendingPayment, processing, shipped, delivered, cancelled }

/// 单个不可变订单实体。
class Order {
  const Order({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  /// Repository 和 family Provider 使用的稳定主键。
  final String id;
  final String title;
  final double totalAmount;

  /// 物流 Stream、乐观取消和列表筛选共同读取的业务状态。
  final OrderStatus status;
  final DateTime createdAt;

  /// “进行中”用于列表筛选，不等同于是否允许取消。
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
    // 当前示例只允许状态变化；其余事实字段保持原值。
    return Order(
      id: id,
      title: title,
      totalAmount: totalAmount,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

/// Repository 的分页返回值，把数据与“是否还有下一页”一起交给 ViewModel。
class OrderPageResult {
  const OrderPageResult({required this.orders, required this.hasMore});
  final List<Order> orders;
  final bool hasMore;
}
