// lib/features/home/view/home_page.dart
//
// 基础 Tab：一个可操作的商品目录，而不是计数器。
// 搜索/筛选展示 watch；按钮命令展示 read；购物车提示展示 listen；
// 单商品数量展示 family+select；购物车汇总展示派生 Provider。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../model/product.dart';
import '../view_model/catalog_view_model.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // Provider 可能因 StatefulShellRoute 已保留同一登录会话的筛选条件；
    // 页面重新创建时输入框必须与 filter.keyword 一致。
    _searchController = TextEditingController(
      text: ref.read(catalogFilterProvider).keyword,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(visibleProductsProvider);
    final filter = ref.watch(catalogFilterProvider);

    // 登录用户切换会重建筛选 Provider；同步输入框，避免“框为空但列表仍在筛选”。
    ref.listen(catalogFilterProvider.select((state) => state.keyword), (
      previous,
      next,
    ) {
      if (_searchController.text == next) return;
      _searchController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });

    // listen 专门处理“状态变化带来的 UI 副作用”，不参与 Widget 构建。
    ref.listen(cartSummaryProvider.select((value) => value.totalQuantity), (
      previous,
      next,
    ) {
      if (previous != null && next > previous) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.cartAdded(next))));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.catalogTitle),
        // 汇总放在独立 ConsumerWidget 中；加购时不会连带重建商品列表父节点。
        actions: const [_CartActions()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _SceneExplanation(),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: AppStrings.searchProducts,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) =>
                ref.read(catalogFilterProvider.notifier).search(value),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text(AppStrings.all),
                selected: filter.category == null,
                onSelected: (_) => ref
                    .read(catalogFilterProvider.notifier)
                    .selectCategory(null),
              ),
              for (final category in ProductCategory.values)
                ChoiceChip(
                  label: Text(_categoryLabel(category)),
                  selected: filter.category == category,
                  onSelected: (_) => ref
                      .read(catalogFilterProvider.notifier)
                      .selectCategory(category),
                ),
              FilterChip(
                label: const Text(AppStrings.favoritesOnly),
                selected: filter.onlyFavorites,
                onSelected: (_) =>
                    ref.read(catalogFilterProvider.notifier).toggleFavorites(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: Text(AppStrings.catalogEmpty)),
            )
          else
            for (final product in products) _ProductCard(product: product),
          const SizedBox(height: AppSpacing.md),
          const _CartSummaryCard(),
        ],
      ),
    );
  }

  String _categoryLabel(ProductCategory category) => switch (category) {
    ProductCategory.phone => AppStrings.phoneCategory,
    ProductCategory.computer => AppStrings.computerCategory,
    ProductCategory.accessory => AppStrings.accessoryCategory,
  };
}

class _SceneExplanation extends StatelessWidget {
  const _SceneExplanation();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text(AppStrings.catalogSceneDescription),
      ),
    );
  }
}

/// 只有右上角购物车区域订阅汇总，避免 cart 变化让整个 HomePage rebuild。
class _CartActions extends ConsumerWidget {
  const _CartActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      cartSummaryProvider.select((summary) => summary.totalQuantity),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: Text(AppStrings.cartItemCount(count))),
        IconButton(
          tooltip: AppStrings.openCart,
          onPressed: () => context.push(RoutePaths.mainCart),
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
      ],
    );
  }
}

/// 汇总卡独立订阅总数和总价；ProductCard 仍只监听自己的商品切片。
class _CartSummaryCard extends ConsumerWidget {
  const _CartSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(cartSummaryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          AppStrings.cartSummary(
            summary.totalQuantity,
            summary.totalPrice.toStringAsFixed(2),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // family 让本卡片只订阅自己的数量；其他商品加购不会重建这个数量。
    final quantity = ref.watch(cartQuantityProvider(product.id));
    final isFavorite = ref.watch(
      favoriteProductIdsProvider.select((ids) => ids.contains(product.id)),
    );

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
                  tooltip: AppStrings.toggleFavorite,
                  onPressed: () => ref
                      .read(favoriteProductIdsProvider.notifier)
                      .toggle(product.id),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
              ],
            ),
            Text(product.description),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('¥${product.price.toStringAsFixed(0)}'),
                const Spacer(),
                if (quantity > 0) ...[
                  IconButton(
                    onPressed: () =>
                        ref.read(cartProvider.notifier).remove(product.id),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$quantity'),
                ],
                IconButton.filledTonal(
                  onPressed: () =>
                      ref.read(cartProvider.notifier).add(product.id),
                  icon: const Icon(Icons.add_shopping_cart),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
