// lib/features/orders/view/orders_page.dart
//
// 异步业务页：初载错误留在页面，创建/取消/分页错误通过独立操作状态提示；
// 单项修改保留旧列表并乐观更新，不把整个页面重新切到 loading。

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
    final feed = ref.watch(orderFeedProvider);
    final orders = ref.watch(visibleOrdersProvider);
    final filter = ref.watch(orderFilterProvider);

    // listen 只监听“操作结果”，首次加载失败仍由 AsyncValue.when 的错误页负责。
    ref.listen(
      orderFeedProvider.select((value) => value.value?.operationResult),
      (previous, next) {
        if (next == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: next.isError
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        );
        ref.read(orderFeedProvider.notifier).consumeOperationResult();
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.ordersTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.reloadOrders,
            onPressed: () => ref.invalidate(orderFeedProvider),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
        onRefresh: () => ref.refresh(orderFeedProvider.future),
        child: feed.when(
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
    final detail = ref.watch(orderDetailProvider(orderId));
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
