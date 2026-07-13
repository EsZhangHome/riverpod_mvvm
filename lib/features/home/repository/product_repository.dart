// lib/features/home/repository/product_repository.dart
//
// 商品 Repository 隔离数据来源。当前是同步本地目录，未来可以换成数据库缓存；
// 远端商品接口则适合改成 AsyncNotifier，页面不需要直接依赖数据源。
//
// 阅读方式：
// 1. ViewModel 只依赖 ProductRepository；
// 2. 当前实现同步返回本地商品，方便聚焦同步 Riverpod API；
// 3. 测试通过 productRepositoryProvider.overrideWith 注入 Fake；
// 4. 将来换数据库/网络实现时，Model 和 View 不需要改。

import '../model/product.dart';

abstract interface class ProductRepository {
  /// 获取完整商品目录。当前同步，因此不需要 AsyncValue。
  List<Product> getProducts();
}

/// 教学环境的本地只读商品数据源。
class LocalProductRepository implements ProductRepository {
  @override
  // const 商品不会被修改；收藏和数量是另外两个独立业务状态。
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
