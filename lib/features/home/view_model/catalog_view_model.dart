// lib/features/home/view_model/catalog_view_model.dart
//
// 商品目录 ViewModel：用真实业务说明同步 Riverpod API 的职责。
// Provider 注入 Repository；三个 Notifier 分别维护筛选、收藏、购物车；
// 派生 Provider 负责组合，避免 View 或 State 保存重复数据。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../global/auth_provider.dart';
import '../model/product.dart';
import '../repository/product_repository.dart';

// 1. Provider：依赖注入。
// 测试可以 override 此 Provider，无需修改 ViewModel 构造函数或使用全局 locator。
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return LocalProductRepository();
});

// 2. Provider：把 Repository 数据暴露给其他 Provider。
final productsProvider = Provider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).getProducts();
});

class CatalogFilterState {
  const CatalogFilterState({
    this.keyword = '',
    this.category,
    this.onlyFavorites = false,
  });

  final String keyword;
  final ProductCategory? category;
  final bool onlyFavorites;

  CatalogFilterState copyWith({
    String? keyword,
    ProductCategory? category,
    bool? onlyFavorites,
    bool clearCategory = false,
  }) {
    return CatalogFilterState(
      keyword: keyword ?? this.keyword,
      category: clearCategory ? null : category ?? this.category,
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
    );
  }
}

// 3. NotifierProvider：表单/筛选等同步状态。
class CatalogFilterNotifier extends Notifier<CatalogFilterState> {
  @override
  CatalogFilterState build() {
    // 登录用户变化时重建瞬时筛选，避免新账号继承上一账号的搜索条件。
    ref.watch(currentUserIdProvider);
    return const CatalogFilterState();
  }

  void search(String keyword) =>
      state = state.copyWith(keyword: keyword.trim());

  void selectCategory(ProductCategory? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
  }

  void toggleFavorites() {
    state = state.copyWith(onlyFavorites: !state.onlyFavorites);
  }
}

// 这是根 Tab 的交互状态，切换 Tab 后仍应保留搜索条件，因此不使用 autoDispose。
// Riverpod 3 会暂停 TickerMode 关闭区域中的订阅；若这里使用 autoDispose，
// 切到“订单”再回来时筛选可能被释放，而 StatefulShellRoute 保留的 TextField
// 仍可能显示旧文字，形成 UI 与 Provider 状态不一致。
final catalogFilterProvider =
    NotifierProvider<CatalogFilterNotifier, CatalogFilterState>(
      CatalogFilterNotifier.new,
    );

// 收藏和购物车是两个独立业务状态，拆开后不同 Widget 可以精准订阅。
class FavoriteProductsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(currentUserIdProvider);
    return const <String>{};
  }

  void toggle(String productId) {
    final next = {...state};
    next.contains(productId) ? next.remove(productId) : next.add(productId);
    state = Set.unmodifiable(next);
  }
}

final favoriteProductIdsProvider =
    NotifierProvider<FavoriteProductsNotifier, Set<String>>(
      FavoriteProductsNotifier.new,
    );

class CartNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    ref.watch(currentUserIdProvider);
    return const <String, int>{};
  }

  void add(String productId) {
    state = Map.unmodifiable({
      ...state,
      productId: (state[productId] ?? 0) + 1,
    });
  }

  void remove(String productId) {
    final next = {...state};
    final quantity = next[productId] ?? 0;
    if (quantity <= 1) {
      next.remove(productId);
    } else {
      next[productId] = quantity - 1;
    }
    state = Map.unmodifiable(next);
  }

  void removeItem(String productId) {
    if (!state.containsKey(productId)) return;
    state = Map.unmodifiable({...state}..remove(productId));
  }

  void clear() => state = const <String, int>{};
}

final cartProvider = NotifierProvider<CartNotifier, Map<String, int>>(
  CartNotifier.new,
);

// 4. 派生 Provider：组合商品、筛选条件、收藏，自己不拥有 state。
final visibleProductsProvider = Provider.autoDispose<List<Product>>((ref) {
  final products = ref.watch(productsProvider);
  final filter = ref.watch(catalogFilterProvider);
  // 只有“只看收藏”开启时才建立收藏依赖。普通浏览时点收藏只重建目标卡片，
  // 不会因为派生列表无条件 watch 整个 Set 而重建页面。
  final favorites = filter.onlyFavorites
      ? ref.watch(favoriteProductIdsProvider)
      : const <String>{};
  final keyword = filter.keyword.toLowerCase();

  return products
      .where((product) {
        final matchesKeyword =
            keyword.isEmpty ||
            product.name.toLowerCase().contains(keyword) ||
            product.description.toLowerCase().contains(keyword);
        final matchesCategory =
            filter.category == null || product.category == filter.category;
        final matchesFavorite =
            !filter.onlyFavorites || favorites.contains(product.id);
        return matchesKeyword && matchesCategory && matchesFavorite;
      })
      .toList(growable: false);
});

// 5. family + select：每个商品卡片只监听自己的数量。
// autoDispose 防止动态商品 id 对应的 family 实例在卡片离开后永久留在容器里。
final cartQuantityProvider = Provider.autoDispose.family<int, String>((
  ref,
  productId,
) {
  return ref.watch(cartProvider.select((cart) => cart[productId] ?? 0));
});

// 6. 派生汇总：总数和总价永远由购物车及商品目录计算，不产生同步问题。
final cartSummaryProvider = Provider<CartSummary>((ref) {
  final cart = ref.watch(cartProvider);
  final products = ref.watch(productsProvider);
  var totalQuantity = 0;
  var totalPrice = 0.0;
  for (final product in products) {
    final quantity = cart[product.id] ?? 0;
    totalQuantity += quantity;
    totalPrice += product.price * quantity;
  }
  return CartSummary(totalQuantity: totalQuantity, totalPrice: totalPrice);
});

/// 购物车详情页使用的派生列表。
///
/// 这里只组合商品信息和数量，不拥有新状态；首页增减数量后，详情页会自动得到
/// 最新结果。页面离开后列表计算即可释放，因此使用 autoDispose。
final cartLineItemsProvider = Provider.autoDispose<List<CartLineItem>>((ref) {
  final cart = ref.watch(cartProvider);
  final products = ref.watch(productsProvider);
  return products
      .where((product) => (cart[product.id] ?? 0) > 0)
      .map(
        (product) =>
            CartLineItem(product: product, quantity: cart[product.id]!),
      )
      .toList(growable: false);
});
