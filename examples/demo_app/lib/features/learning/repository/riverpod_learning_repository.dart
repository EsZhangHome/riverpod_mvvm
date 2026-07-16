// lib/features/learning/repository/riverpod_learning_repository.dart
//
// 教学内容也通过 Repository 提供。未来可以改成本地 JSON、Markdown 或远端配置，
// View 和 ViewModel 都不需要知道内容来源。
//
// 本文件中的长字符串是“展示给学习者的示例源码”，不会被 Dart 执行；
// 真正可运行的完整实现应继续对照对应 feature 源文件阅读。

import '../../../localization/demo_strings.dart';
import '../model/riverpod_lesson.dart';

abstract interface class RiverpodLearningRepository {
  /// 返回按基础、异步、全局排列的完整课程集合。
  List<RiverpodLesson> getLessons();
}

/// 使用编译期常量保存课程的本地实现，不产生 IO 或网络请求。
class LocalRiverpodLearningRepository implements RiverpodLearningRepository {
  const LocalRiverpodLearningRepository();

  @override
  // 返回不可变 const 列表；ViewModel 只能选择课程，不能修改课程内容。
  List<RiverpodLesson> getLessons() => _lessons;

  // 枚举顺序和列表顺序保持一致，上一站/下一站才能按预期导航。
  static const List<RiverpodLesson> _lessons = [
    RiverpodLesson(
      stage: RiverpodLessonStage.basic,
      scene: DemoStrings.basicLearningScene,
      apis: DemoStrings.basicLearningApis,
      dataFlow: DemoStrings.basicLearningDataFlow,
      interaction: DemoStrings.basicLearningInteraction,
      codeEntry: DemoStrings.basicLearningCodeEntry,
      codeExamples: [
        RiverpodCodeExample(
          title: 'Provider + NotifierProvider',
          code: r'''// Provider 只负责依赖注入或同步只读计算。
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return LocalProductRepository();
});

// NotifierProvider 持有可修改的同步业务状态。
final cartProvider = NotifierProvider<CartNotifier, Map<String, int>>(
  CartNotifier.new,
);''',
        ),
        RiverpodCodeExample(
          title: 'watch / read / listen / select / family',
          code: r'''// watch：参与构建，Provider 变化时重新构建当前 Widget。
final quantity = ref.watch(cartQuantityProvider(product.id));

// read：按钮发送命令，不建立监听关系。
ref.read(cartProvider.notifier).add(product.id);

// select：只关心 State 的一个切片。
final count = ref.watch(
  cartSummaryProvider.select((value) => value.totalQuantity),
);

// listen：处理 SnackBar、导航等一次性 UI 副作用。
ref.listen(cartSummaryProvider, (previous, next) {
  // 根据变化展示提示，不返回 Widget。
});''',
        ),
        RiverpodCodeExample(
          title: '派生 Provider',
          code: r'''// 派生数据不再保存第二份 State，始终从源状态计算。
final cartSummaryProvider = Provider<CartSummary>((ref) {
  final cart = ref.watch(cartProvider);
  final products = ref.watch(productsProvider);
  return calculateSummary(cart, products);
});''',
        ),
      ],
    ),
    RiverpodLesson(
      stage: RiverpodLessonStage.async,
      scene: DemoStrings.asyncLearningScene,
      apis: DemoStrings.asyncLearningApis,
      dataFlow: DemoStrings.asyncLearningDataFlow,
      interaction: DemoStrings.asyncLearningInteraction,
      codeEntry: DemoStrings.asyncLearningCodeEntry,
      codeExamples: [
        RiverpodCodeExample(
          title: 'AsyncNotifier + AsyncValue',
          code: r'''final orderFeedProvider =
    AsyncNotifierProvider<OrderFeedNotifier, OrderFeedState>(
  OrderFeedNotifier.new,
);

class OrderFeedNotifier extends AsyncNotifier<OrderFeedState> {
  @override
  Future<OrderFeedState> build() async {
    final repository = ref.watch(orderRepositoryProvider);
    final page = await repository.fetchOrders(page: 1);
    return OrderFeedState(orders: page.orders);
  }
}

final feed = ref.watch(orderFeedProvider);
return feed.when(
  loading: () => const LoadingView(),
  // 不把 error.toString() 直接展示给用户，统一转换为安全、可本地化的文案。
  error: (error, stack) => ErrorView(
    message: FailureMessageResolver.resolve(error),
  ),
  data: (state) => OrderList(orders: state.orders),
);''',
        ),
        RiverpodCodeExample(
          title: 'family + StreamProvider',
          code: r'''// 同一种查询按订单 id 隔离状态和生命周期。
final orderDetailProvider = FutureProvider.autoDispose
    .family<Order, String>((ref, id) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.fetchOrder(id);
});

final orderStatusProvider = StreamProvider.autoDispose
    .family<OrderStatus, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).watchOrderStatus(id);
});''',
        ),
        RiverpodCodeExample(
          title: 'refresh / invalidate / 请求取消',
          code: r'''// refresh：立即重建并等待新的 Future，适合下拉刷新。
await ref.refresh(orderFeedProvider.future);

// invalidate：销毁当前状态；有活动监听时会在后续帧重建，否则等下次读取再创建。
ref.invalidate(orderDetailProvider(orderId));

// Provider 销毁时取消未完成请求；上层不需要知道底层使用 Dio 还是其他网络库。
final cancelToken = RequestCancellationToken();
ref.onDispose(() => cancelToken.cancel('page disposed'));
await repository.fetchOrder(orderId, cancelToken: cancelToken);''',
        ),
      ],
    ),
    RiverpodLesson(
      stage: RiverpodLessonStage.global,
      scene: DemoStrings.globalLearningScene,
      apis: DemoStrings.globalLearningApis,
      dataFlow: DemoStrings.globalLearningDataFlow,
      interaction: DemoStrings.globalLearningInteraction,
      codeEntry: DemoStrings.globalLearningCodeEntry,
      codeExamples: [
        RiverpodCodeExample(
          title: 'App 级登录态与主题',
          code: r'''// 非 autoDispose：状态与 App/登录会话同生命周期。
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);

// MaterialApp 只监听真正影响主题的字段。
final themeMode = ref.watch(
  themeProvider.select((state) => state.themeMode),
);''',
        ),
        RiverpodCodeExample(
          title: '服务注入与跨页面共享',
          code:
              r'''final appInfoServiceProvider = Provider<AppInfoService>((ref) {
  return PlatformAppInfoService();
});

final appInfoProvider = FutureProvider.autoDispose<AppInfo>((ref) {
  return ref.watch(appInfoServiceProvider).getAppInfo();
});

// 用户 id 是商品、购物车和订单的会话边界。
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider.select((state) => state.currentUser?.id));
});''',
        ),
        RiverpodCodeExample(
          title: 'Provider override',
          code: r'''// 测试替换 Service/Repository，不启动真实插件或网络请求。
final container = ProviderContainer(
  overrides: [
    appInfoServiceProvider.overrideWithValue(FakeAppInfoService()),
  ],
);
addTearDown(container.dispose);

final appInfo = await container.read(appInfoProvider.future);''',
        ),
      ],
    ),
  ];
}
