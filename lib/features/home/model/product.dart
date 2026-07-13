// lib/features/home/model/product.dart
//
// 商品领域模型。Model 保持纯 Dart、不可变，不知道 Riverpod、Widget 或 Repository。
//
// 数据关系：Product 是商品事实数据；CartNotifier 只保存 productId -> quantity；
// CartLineItem 和 CartSummary 都由 Provider 组合计算，不单独持久化。

/// 商品业务分类。View 负责把枚举转换为本地化文案。
enum ProductCategory { phone, computer, accessory }

/// 商品目录中的不可变商品实体。
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
  });

  /// 稳定业务主键，也是收藏 Set 和购物车 Map 使用的关联键。
  final String id;

  /// 用户可见的基础信息，由 Repository 提供。
  final String name;
  final String description;
  final ProductCategory category;
  final double price;
}

/// 购物车顶部角标和底部合计区域使用的只读汇总值。
class CartSummary {
  const CartSummary({required this.totalQuantity, required this.totalPrice});

  /// 所有商品数量之和，不是购物车中不同商品的种类数。
  final int totalQuantity;

  /// 每个商品单价乘数量后求和。
  final double totalPrice;
}

/// 购物车展示行。它由商品目录和购物车数量派生，不作为第二份可变状态保存。
class CartLineItem {
  const CartLineItem({required this.product, required this.quantity});

  /// 完整商品信息来自 productsProvider，数量来自 cartProvider。
  final Product product;
  final int quantity;

  /// 小计始终实时计算，商品价格或数量变化时不会遗留旧值。
  double get subtotal => product.price * quantity;
}
