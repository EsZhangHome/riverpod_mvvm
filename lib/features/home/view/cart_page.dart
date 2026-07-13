// lib/features/home/view/cart_page.dart
//
// 购物车详情 View：只 watch 派生明细和汇总，通过 read 调用 CartNotifier 命令。
// 明细不是页面本地状态，因此从商品页进入后仍能看到同一份购物车数据。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../model/product.dart';
import '../view_model/catalog_view_model.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartLineItemsProvider);
    final summary = ref.watch(cartSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.cartTitle),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: AppStrings.clearCart,
              onPressed: () => _confirmClear(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyCartView()
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _CartItemCard(item: items[index]),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_checkout),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              AppStrings.cartTotal(
                                summary.totalQuantity,
                                summary.totalPrice.toStringAsFixed(2),
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.clearCartConfirmTitle),
        content: const Text(AppStrings.clearCartConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.keepCart),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.confirmClearCart),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).clear();
    }
  }
}

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({required this.item});

  final CartLineItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = item.product;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.removeCartItem,
                  onPressed: () =>
                      ref.read(cartProvider.notifier).removeItem(product.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(AppStrings.cartUnitPrice(product.price.toStringAsFixed(2))),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.cartSubtotal(item.subtotal.toStringAsFixed(2)),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: () =>
                      ref.read(cartProvider.notifier).remove(product.id),
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () =>
                      ref.read(cartProvider.notifier).add(product.id),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove_shopping_cart_outlined, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.cartEmpty,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(AppStrings.cartEmptyDescription),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(RoutePaths.mainHome),
              child: const Text(AppStrings.continueShopping),
            ),
          ],
        ),
      ),
    );
  }
}
