import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/home/model/product.dart';
import 'package:riverpod_mvvm/features/home/repository/product_repository.dart';
import 'package:riverpod_mvvm/features/home/view_model/catalog_view_model.dart';
import 'package:riverpod_mvvm/global/auth_provider.dart';
import 'package:riverpod_mvvm/shared/models/user_model.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    token: 'token-a',
    currentUser: UserModel(id: 'user-a', name: 'A', email: 'a@test.com'),
  );

  void switchUser(String id) {
    // 模拟同一 ProviderContainer 内账号切换，触发用户级状态重建。
    state = AuthState(
      token: 'token-$id',
      currentUser: UserModel(id: id, name: id, email: '$id@test.com'),
    );
  }
}

class _FakeProductRepository implements ProductRepository {
  @override
  List<Product> getProducts() => const [
    Product(
      id: 'phone',
      name: '测试手机',
      description: 'test',
      category: ProductCategory.phone,
      price: 100,
    ),
    Product(
      id: 'keyboard',
      name: '测试键盘',
      description: 'test',
      category: ProductCategory.accessory,
      price: 20,
    ),
  ];
}

void main() {
  test(
    'catalog filters and cart summary are derived from source providers',
    () {
      // Arrange：替换全局会话和商品数据，保证价格与 id 可预测。
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_FakeAuthNotifier.new),
          productRepositoryProvider.overrideWith(
            (ref) => _FakeProductRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final filterSubscription = container.listen(
        catalogFilterProvider,
        (_, _) {},
      );
      addTearDown(filterSubscription.close);

      // Act 1：选择手机分类，visibleProductsProvider 应只剩手机。
      container
          .read(catalogFilterProvider.notifier)
          .selectCategory(ProductCategory.phone);
      expect(container.read(visibleProductsProvider).single.id, 'phone');

      // Act 2：添加两台手机和一个键盘，汇总应从 cartProvider 派生。
      container.read(cartProvider.notifier)
        ..add('phone')
        ..add('phone')
        ..add('keyboard');

      // Assert：总数、总价、family 数量与详情行必须一致。
      final summary = container.read(cartSummaryProvider);
      expect(summary.totalQuantity, 3);
      expect(summary.totalPrice, 220);
      expect(container.read(cartQuantityProvider('phone')), 2);
      final lineItems = container.read(cartLineItemsProvider);
      expect(lineItems.map((item) => item.product.id), ['phone', 'keyboard']);
      expect(lineItems.first.quantity, 2);
      expect(lineItems.first.subtotal, 200);
    },
  );

  test('普通浏览收藏只通知目标订阅，切换账号会清理用户级状态', () async {
    // Arrange：统计 visibleProductsProvider 实际通知次数。
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_FakeAuthNotifier.new),
        productRepositoryProvider.overrideWith(
          (ref) => _FakeProductRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    var visibleListNotifications = 0;
    final visibleSubscription = container.listen(
      visibleProductsProvider,
      (_, _) => visibleListNotifications++,
      fireImmediately: true,
    );
    addTearDown(visibleSubscription.close);

    // Act 1：普通浏览时收藏不应重算整个列表；搜索会。
    container.read(favoriteProductIdsProvider.notifier).toggle('phone');
    container.read(cartProvider.notifier).add('phone');
    container.read(catalogFilterProvider.notifier).search('测试手机');
    await container.pump();

    // onlyFavorites=false 时，visibleProducts 不依赖收藏 Set。
    expect(visibleListNotifications, 2); // 首次通知 + 搜索条件变化
    expect(container.read(favoriteProductIdsProvider), {'phone'});
    expect(container.read(cartProvider), {'phone': 1});

    // Act 2：切换账号，依赖 currentUserIdProvider 的状态全部重建。
    (container.read(authProvider.notifier) as _FakeAuthNotifier).switchUser(
      'user-b',
    );
    await container.pump();

    expect(container.read(catalogFilterProvider).keyword, isEmpty);
    expect(container.read(favoriteProductIdsProvider), isEmpty);
    expect(container.read(cartProvider), isEmpty);
  });
}

// 商品目录 Provider 单元测试：通过 Fake Auth/Repository 验证筛选、收藏、购物车、
// 派生明细和用户会话边界，不依赖任何 Widget 或平台插件。
