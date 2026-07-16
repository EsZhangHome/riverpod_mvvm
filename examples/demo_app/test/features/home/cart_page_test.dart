import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm_demo/localization/demo_strings.dart';
import 'package:riverpod_mvvm_demo/features/home/model/product.dart';
import 'package:riverpod_mvvm_demo/features/home/home_providers.dart';
import 'package:riverpod_mvvm_demo/features/home/repository/product_repository.dart';
import 'package:riverpod_mvvm_demo/features/home/view/cart_page.dart';
import 'package:riverpod_mvvm_demo/features/home/view_model/catalog_view_model.dart';

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
  // 直接从“两台测试手机”开始，省去先渲染商品页再点击的准备步骤。
  Map<String, int> build() => const {'phone': 2};
}

void main() {
  testWidgets('购物车页展示共享明细，支持减购和确认清空', (tester) async {
    // Arrange 1：固定为常见小屏尺寸，主动捕获 Row 溢出问题。
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Arrange 2：替换商品 Repository 和购物车初始 State，再挂载真实 CartPage。
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

    // Assert 1：派生明细和汇总使用相同数量、价格。
    expect(find.text(DemoStrings.cartTitle), findsOneWidget);
    expect(find.text('测试手机'), findsOneWidget);
    expect(find.text(DemoStrings.cartSubtotal('200.00')), findsOneWidget);
    expect(find.text(DemoStrings.cartTotal(2, '200.00')), findsOneWidget);

    // Act 1：点击减一后，只调用真实 CartNotifier.remove。
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text(DemoStrings.cartTotal(1, '100.00')), findsOneWidget);

    // Act 2：清空按钮必须先出现确认弹窗，确认后才改变 Provider。
    await tester.tap(find.byTooltip(DemoStrings.clearCart));
    await tester.pumpAndSettle();
    expect(find.text(DemoStrings.clearCartConfirmTitle), findsOneWidget);
    await tester.tap(find.text(DemoStrings.confirmClearCart));
    await tester.pumpAndSettle();

    // Assert 2：唯一源状态清空后，明细卡片和汇总一起消失。
    expect(find.text(DemoStrings.cartEmpty), findsOneWidget);
    expect(find.text('测试手机'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

// 购物车 Widget 测试：通过 Provider override 构造确定数据，验证 View 与
// CartNotifier 使用同一份状态，同时覆盖窄屏布局和确认清空副作用。
