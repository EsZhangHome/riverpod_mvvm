import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/l10n/app_strings.dart';
import 'package:riverpod_mvvm/features/home/model/product.dart';
import 'package:riverpod_mvvm/features/home/repository/product_repository.dart';
import 'package:riverpod_mvvm/features/home/view/cart_page.dart';
import 'package:riverpod_mvvm/features/home/view_model/catalog_view_model.dart';

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
  ];
}

class _SeedCartNotifier extends CartNotifier {
  @override
  Map<String, int> build() => const {'phone': 2};
}

void main() {
  testWidgets('购物车页展示共享明细，支持减购和确认清空', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWith(
            (ref) => _FakeProductRepository(),
          ),
          cartProvider.overrideWith(_SeedCartNotifier.new),
        ],
        child: const MaterialApp(home: CartPage()),
      ),
    );

    expect(find.text(AppStrings.cartTitle), findsOneWidget);
    expect(find.text('测试手机'), findsOneWidget);
    expect(find.text(AppStrings.cartSubtotal('200.00')), findsOneWidget);
    expect(find.text(AppStrings.cartTotal(2, '200.00')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text(AppStrings.cartTotal(1, '100.00')), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.clearCart));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.clearCartConfirmTitle), findsOneWidget);
    await tester.tap(find.text(AppStrings.confirmClearCart));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.cartEmpty), findsOneWidget);
    expect(find.text('测试手机'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
