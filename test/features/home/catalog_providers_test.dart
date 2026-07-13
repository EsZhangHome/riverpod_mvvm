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

      container
          .read(catalogFilterProvider.notifier)
          .selectCategory(ProductCategory.phone);
      expect(container.read(visibleProductsProvider).single.id, 'phone');

      container.read(cartProvider.notifier)
        ..add('phone')
        ..add('phone')
        ..add('keyboard');

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

    container.read(favoriteProductIdsProvider.notifier).toggle('phone');
    container.read(cartProvider.notifier).add('phone');
    container.read(catalogFilterProvider.notifier).search('测试手机');
    await container.pump();

    // onlyFavorites=false 时，visibleProducts 不依赖收藏 Set。
    expect(visibleListNotifications, 2); // 首次通知 + 搜索条件变化
    expect(container.read(favoriteProductIdsProvider), {'phone'});
    expect(container.read(cartProvider), {'phone': 1});

    (container.read(authProvider.notifier) as _FakeAuthNotifier).switchUser(
      'user-b',
    );
    await container.pump();

    expect(container.read(catalogFilterProvider).keyword, isEmpty);
    expect(container.read(favoriteProductIdsProvider), isEmpty);
    expect(container.read(cartProvider), isEmpty);
  });
}
