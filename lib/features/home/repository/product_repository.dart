// lib/features/home/repository/product_repository.dart
//
// 商品 Repository 隔离数据来源。当前是同步本地目录，未来可以换成数据库缓存；
// 远端商品接口则适合改成 AsyncNotifier，页面不需要直接依赖数据源。

import '../model/product.dart';

abstract interface class ProductRepository {
  List<Product> getProducts();
}

class LocalProductRepository implements ProductRepository {
  @override
  List<Product> getProducts() => const [
    Product(
      id: 'iphone',
      name: '旗舰手机',
      description: '适合演示搜索、分类、收藏和购物车数量。',
      category: ProductCategory.phone,
      price: 5999,
    ),
    Product(
      id: 'fold',
      name: '折叠屏手机',
      description: '同一商品状态由多个派生 Provider 组合展示。',
      category: ProductCategory.phone,
      price: 8999,
    ),
    Product(
      id: 'laptop',
      name: '轻薄笔记本',
      description: 'Repository 可在测试中通过 Provider override 替换。',
      category: ProductCategory.computer,
      price: 7499,
    ),
    Product(
      id: 'keyboard',
      name: '机械键盘',
      description: '购物车总数和总价不重复保存，由 Provider 实时计算。',
      category: ProductCategory.accessory,
      price: 699,
    ),
    Product(
      id: 'headphone',
      name: '降噪耳机',
      description: 'family 根据商品 id 精准监听购物车数量。',
      category: ProductCategory.accessory,
      price: 1299,
    ),
  ];
}
