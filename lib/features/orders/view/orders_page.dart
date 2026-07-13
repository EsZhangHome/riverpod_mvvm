// lib/features/orders/view/orders_page.dart
//
// 异步业务页：初载错误留在页面，创建/取消/分页错误通过独立操作状态提示；
// 单项修改保留旧列表并乐观更新，不把整个页面重新切到 loading。
//
// 页面执行顺序：
// 1. watch AsyncValue 列表、派生可见列表和同步筛选；
// 2. listen 一次性操作结果并展示 SnackBar；
// 3. AsyncValue.when 只处理首屏 loading/error/data；
// 4. 分页、创建、取消通过 State 内局部标志渲染，不遮住已有列表；
// 5. 点击订单打开 family 详情和 family 实时物流，关闭弹窗后自动释放。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../model/order.dart';
import '../view_model/order_view_model.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // feed 保留完整异步和命令状态；orders 只包含筛选后的展示结果。
    final feed = ref.watch(orderFeedProvider);
    final orders = ref.watch(visibleOrdersProvider);
    final filter = ref.watch(orderFilterProvider);

    // listen 只监听“操作结果”，首次加载失败仍由 AsyncValue.when 的错误页负责。
    ref.listen(
      orderFeedProvider.select((value) => value.value?.operationResult),
      (previous, next) {
        if (next == null) return;
        // View 负责颜色和 SnackBar；ViewModel 只产生与平台无关的消息结果。
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: next.isError
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        );
        // 展示后立即消费，避免 Widget 重建时重复弹出同一消息。
        ref.read(orderFeedProvider.notifier).consumeOperationResult();
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.ordersTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.reloadOrders,
            // invalidate 丢弃当前 Provider 状态并重新执行 AsyncNotifier.build。
            onPressed: () => ref.invalidate(orderFeedProvider),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // 创建进行中禁用按钮，避免同一命令并发提交。
        onPressed: feed.value?.isCreating == true
            ? null
            : () => ref.read(orderFeedProvider.notifier).createOrder(),
        icon: feed.value?.isCreating == true
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text(AppStrings.createOrder),
      ),
      body: RefreshIndicator(
        // refresh 返回新的 Future，RefreshIndicator 会等待刷新真正完成。
        onRefresh: () => ref.refresh(orderFeedProvider.future),
        child: feed.when(
          // 这三个分支只对应“首屏 Provider 状态”。
          loading: () => ListView(
            children: const [
              SizedBox(height: 260),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 220),
              const Center(child: Text(AppStrings.ordersLoadFailed)),
              TextButton(
                onPressed: () => ref.invalidate(orderFeedProvider),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
          data: (state) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(AppStrings.ordersSceneDescription),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<OrderFilter>(
                segments: const [
                  ButtonSegment(
                    value: OrderFilter.all,
                    label: Text(AppStrings.all),
                  ),
                  ButtonSegment(
                    value: OrderFilter.active,
                    label: Text(AppStrings.activeOrders),
                  ),
                  ButtonSegment(
                    value: OrderFilter.finished,
                    label: Text(AppStrings.finishedOrders),
                  ),
                ],
                selected: {filter},
                // 筛选是同步命令，不需要等待 Future。
                onSelectionChanged: (value) =>
                    ref.read(orderFilterProvider.notifier).change(value.single),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (orders.isEmpty)
                const Center(child: Text(AppStrings.noFilteredOrders))
              else
                for (final order in orders)
                  _OrderCard(
                    order: order,
                    isUpdating: state.updatingIds.contains(order.id),
                  ),
              const SizedBox(height: AppSpacing.md),
              if (state.hasMore)
                OutlinedButton(
                  onPressed: state.isLoadingMore
                      ? null
                      // 加载更多保留现有订单，只切换底部按钮 loading。
                      : () => ref.read(orderFeedProvider.notifier).loadMore(),
                  child: state.isLoadingMore
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(AppStrings.loadNextPage),
                )
              else
                const Center(child: Text(AppStrings.noMoreOrders)),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order, required this.isUpdating});
  final Order order;
  final bool isUpdating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        // 每个 id 对应独立详情和实时物流 Provider 实例。
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _OrderDetailDialog(orderId: order.id),
        ),
        title: Text(order.title),
        subtitle: Text(
          '${_statusLabel(order.status)} · ¥${order.totalAmount.toStringAsFixed(2)}',
        ),
        trailing: isUpdating
            ? const CircularProgressIndicator()
            : order.canCancel
            ? TextButton(
                // View 只发命令；乐观更新和失败回滚全部由 ViewModel 负责。
                onPressed: () =>
                    ref.read(orderFeedProvider.notifier).cancelOrder(order.id),
                child: const Text(AppStrings.cancel),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _OrderDetailDialog extends ConsumerWidget {
  const _OrderDetailDialog({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // family 参数是 orderId：不同弹窗不会共享错误或 loading 状态。
    final detail = ref.watch(orderDetailProvider(orderId));
    // StreamProvider 将每次物流事件包装成 AsyncValue<OrderStatus>。
    final liveStatus = ref.watch(orderStatusProvider(orderId));
    return AlertDialog(
      title: const Text(AppStrings.orderDetail),
      content: detail.when(
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => const Text(AppStrings.orderDetailLoadFailed),
        data: (order) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.title),
            const SizedBox(height: AppSpacing.md),
            const Text(AppStrings.orderDetailCacheDescription),
            const SizedBox(height: AppSpacing.md),
            Text(
              liveStatus.when(
                loading: () => AppStrings.connectingLogistics,
                error: (error, _) => AppStrings.logisticsConnectionFailed,
                data: (status) =>
                    AppStrings.liveLogistics(_statusLabel(status)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.close),
        ),
      ],
    );
  }
}

String _statusLabel(OrderStatus status) => switch (status) {
  OrderStatus.pendingPayment => AppStrings.pendingPayment,
  OrderStatus.processing => AppStrings.processing,
  OrderStatus.shipped => AppStrings.shipped,
  OrderStatus.delivered => AppStrings.delivered,
  OrderStatus.cancelled => AppStrings.cancelled,
};
