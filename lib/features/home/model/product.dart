// lib/features/home/model/product.dart
//
// 商品领域模型。Model 保持纯 Dart、不可变，不知道 Riverpod、Widget 或 Repository。

enum ProductCategory { phone, computer, accessory }

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
  });

  final String id;
  final String name;
  final String description;
  final ProductCategory category;
  final double price;
}

class CartSummary {
  const CartSummary({required this.totalQuantity, required this.totalPrice});
  final int totalQuantity;
  final double totalPrice;
}

/// 购物车展示行。它由商品目录和购物车数量派生，不作为第二份可变状态保存。
class CartLineItem {
  const CartLineItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;
}
