// lib/features/home/view/cart_page.dart
//
// 购物车详情 View：只 watch 派生明细和汇总，通过 read 调用 CartNotifier 命令。
// 明细不是页面本地状态，因此从商品页进入后仍能看到同一份购物车数据。
//
// 页面执行顺序：
// 1. watch cartLineItemsProvider 和 cartSummaryProvider；
// 2. 空列表显示返回购物入口，非空列表渲染每个 CartLineItem；
// 3. 增减、移除都 read CartNotifier，页面不直接修改集合；
// 4. 清空先由 View 弹确认框，确认后才调用 clear；
// 5. cartProvider 更新后，明细、总数和总价一起重新派生。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/localization/app_strings.dart';
import '../../../shared/navigation/route_paths.dart';
import '../../../shared/theme/app_spacing.dart';
import '../model/product.dart';
import '../view_model/catalog_view_model.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 两者都来自同一个 cartProvider，不会出现明细已空但总价仍存在。
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
          // 空状态由派生列表决定，不额外维护 isEmpty 布尔值。
          ? const _EmptyCartView()
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    // ListView 只接收展示模型，不知道 Map 的存储结构。
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
    // showDialog 是 UI 副作用，必须留在 View，ViewModel 不依赖 BuildContext。
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
    // null 表示系统返回键关闭；只有明确确认才修改业务状态。
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
    // item 是派生快照；按钮仍以 product.id 向唯一源 CartNotifier 发送命令。
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
                  // 整项删除，无论当前数量是多少都移除 productId。
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
                  // 数量为 1 时 remove 会移除整项，派生列表随即删除本卡片。
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
              // 正常从首页 push 进来时 pop；深链进入时回到商品根路由。
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
