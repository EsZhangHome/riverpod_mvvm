// lib/core/l10n/app_strings.dart
//
// 作用：集中管理 App 中所有用户可见的文案字符串。
//
// 设计要点：
// 1. 固定文案使用 static const；带占位参数的文案使用静态格式化方法
// 2. 当前只支持中文，后续可扩展为 arb 文件实现国际化
// 3. 集中管理的好处：文案变更时只需改这一个文件，不需要搜索整个项目
// 4. 分类清晰：导航类、操作类、错误提示类、Mock 提示类
//
// 国际化扩展方式：
// 1. 安装 flutter_localizations 依赖（已安装）
// 2. 创建 lib/l10n/app_zh.arb 和 lib/l10n/app_en.arb
// 3. 在 l10n.yaml 中配置
// 4. 使用 AppLocalizations.of(context).xxx 替换 AppStrings.xxx
// 5. 页面代码改动最小，因为 AppStrings 是集中管理的

/// App 文案集中管理。
///
/// 当前先用静态常量，后续接 arb 文件时页面代码改动最小。
/// 不要在页面中直接写中文字符串。
class AppStrings {
  const AppStrings._();

  // ==================== 导航类 ====================

  /// App 名称
  static const String appName = 'MVVM Demo';

  /// 商品目录 Tab 标题
  static const String home = '商品';

  /// 订单中心 Tab 标题
  static const String orders = '订单';

  /// 我的与设置 Tab 标题
  static const String mine = '我的';

  /// 个人中心页面标题
  static const String profile = '个人中心';

  // ==================== Riverpod 实战页 ====================

  static const String learningPathTitle = 'Riverpod 实战学习路径';
  static const String learningCenterTitle = 'Riverpod 学习中心';
  static const String openRiverpodLearning = '打开 Riverpod 学习中心';
  static const String learningPathDescription =
      '基础 → 异步 → 全局；每一站都按 Model → Repository → ViewModel → View 阅读。';
  static const String learningBasic = '基础';
  static const String learningAsync = '异步';
  static const String learningGlobal = '全局';
  static const String learningScene = '场景';
  static const String learningApis = 'Riverpod API';
  static const String learningDataFlow = '数据流';
  static const String learningInteraction = '可操作 UI';
  static const String learningCodeEntry = '代码入口';
  static const String learningCodeExamples = '核心示例代码';
  static const String learningPrevious = '上一站';
  static const String learningNext = '下一站';
  static const String learningOpenPractice = '进入对应业务实战';

  static String learningCurrentStage(int index, String stage) =>
      '第 $index 站 · $stage';

  static const String catalogTitle = '商品与购物车';
  static const String cartTitle = '购物车';
  static const String openCart = '查看购物车';
  static const String clearCart = '清空购物车';
  static const String removeCartItem = '从购物车移除';
  static const String cartEmpty = '购物车还是空的';
  static const String cartEmptyDescription = '返回商品页选择喜欢的商品吧';
  static const String continueShopping = '继续购物';
  static const String clearCartConfirmTitle = '确认清空购物车？';
  static const String clearCartConfirmMessage = '清空后需要重新添加商品。';
  static const String keepCart = '保留';
  static const String confirmClearCart = '确认清空';
  static const String searchProducts = '搜索商品';
  static const String all = '全部';
  static const String favoritesOnly = '只看收藏';
  static const String catalogEmpty = '没有符合条件的商品';
  static const String phoneCategory = '手机';
  static const String computerCategory = '电脑';
  static const String accessoryCategory = '配件';
  static const String toggleFavorite = '收藏或取消收藏';
  static const String basicLearningScene = '商品搜索、分类、收藏与购物车，用同步业务先理解状态所有权。';
  static const String basicLearningApis =
      'Provider、NotifierProvider、派生 Provider、family、watch / read / listen / select';
  static const String basicLearningDataFlow =
      'ProductRepository → Provider 注入 → Notifier/派生 Provider → ConsumerWidget';
  static const String basicLearningInteraction =
      '搜索和筛选商品、收藏、增减购物车；观察局部重建与加购 SnackBar。';
  static const String basicLearningCodeEntry =
      'features/home/model → repository → view_model/catalog_view_model.dart → view/home_page.dart';
  static const String catalogSceneDescription =
      '业务场景：本地商品目录 + 搜索筛选 + 收藏 + 购物车。\n'
      '学习重点：Provider DI、同步 Notifier、派生状态、family、select、read/listen。';

  static String cartItemCount(int count) => '$count 件';
  static String cartAdded(int count) => '已加入购物车，共 $count 件商品';
  static String cartSummary(int count, String price) =>
      '购物车：$count 件 / ¥$price';
  static String cartUnitPrice(String price) => '单价：¥$price';
  static String cartSubtotal(String price) => '小计：¥$price';
  static String cartTotal(int count, String price) => '共 $count 件商品，合计 ¥$price';

  static const String ordersTitle = '订单中心';
  static const String reloadOrders = '重新加载订单';
  static const String createOrder = '创建订单';
  static const String ordersLoadFailed = '订单加载失败，请稍后重试';
  static const String asyncLearningScene = '订单初载、下拉刷新、分页、创建、乐观取消、详情缓存与实时物流。';
  static const String asyncLearningApis =
      'AsyncNotifierProvider、AsyncValue、FutureProvider.family、StreamProvider.family、refresh / invalidate';
  static const String asyncLearningDataFlow =
      'OrderRepository → AsyncNotifier → AsyncValue<OrderFeedState> → View；详情和物流按订单 id 隔离';
  static const String asyncLearningInteraction =
      '下拉刷新、加载下一页、创建和取消订单、打开详情；观察 loading/error/data、回滚和自动取消请求。';
  static const String asyncLearningCodeEntry =
      'features/orders/model → repository → view_model/order_view_model.dart → view/orders_page.dart';
  static const String ordersSceneDescription =
      '业务场景：订单分页、下拉刷新、创建、取消、详情缓存和物流流。\n'
      '学习重点：保留旧列表、乐观更新、失败回滚和参数化 Provider。';
  static const String activeOrders = '进行中';
  static const String finishedOrders = '已结束';
  static const String noFilteredOrders = '当前筛选条件下没有订单';
  static const String loadNextPage = '加载下一页';
  static const String noMoreOrders = '没有更多订单了';
  static const String cancel = '取消';
  static const String orderDetail = '订单详情';
  static const String orderDetailLoadFailed = '订单详情加载失败';
  static const String orderDetailCacheDescription =
      '详情会在弹窗关闭后短期缓存（FutureProvider.family + keepAlive）';
  static const String connectingLogistics = '正在连接物流状态…';
  static const String logisticsConnectionFailed = '物流状态连接失败';
  static const String close = '关闭';
  static const String pendingPayment = '待付款';
  static const String processing = '处理中';
  static const String shipped = '已发货';
  static const String delivered = '已送达';
  static const String cancelled = '已取消';
  static const String orderLoadMoreFailed = '加载更多失败，请重试';
  static const String orderCreated = '订单创建成功';
  static const String orderCreateFailed = '订单创建失败，请重试';
  static const String orderCancelled = '订单已取消';
  static const String orderCancelRolledBack = '取消失败，订单状态已恢复';

  static String orderMissing(String id) => '订单不存在：$id';
  static String liveLogistics(String status) => '实时物流：$status';

  static const String mineTitle = '我的与设置';
  static const String globalLearningScene = '登录会话、主题持久化、App 信息与网络状态，明确跨页面共享边界。';
  static const String globalLearningApis =
      'App 级 Provider、NotifierProvider、FutureProvider、StreamProvider、select、override、autoDispose';
  static const String globalLearningDataFlow =
      'Service / Storage → App 级或服务 Provider → MaterialApp / GoRouter / 页面 Consumer';
  static const String globalLearningInteraction =
      '切换全局主题、刷新 App 信息、观察网络流、退出登录；确认跨页面共享与用户切换后的状态清理。';
  static const String globalLearningCodeEntry =
      'global/auth_provider.dart + theme_provider.dart → features/mine/view_model → view';
  static const String appNotifierTitle = 'App 级 NotifierProvider';
  static const String appNotifierDescription =
      'authProvider 跨页面共享登录态；GoRouter 也监听它执行重定向。';
  static const String selectGlobalStateTitle = 'select 监听全局 State';
  static const String selectGlobalStateDescription =
      '主题卡片只监听 themeMode，不关心 ThemeState 的其他字段。';
  static const String globalDarkTheme = '全局深色主题';
  static const String globalDarkThemeDescription =
      '修改后 MaterialApp 和所有页面同步更新，并持久化到本地。';
  static const String futureServiceTitle = 'FutureProvider + Service DI';
  static const String futureServiceDescription =
      'AppInfoService 被 Provider 注入，FutureProvider 转换为 AsyncValue。';
  static const String readingAppInfo = '正在读取 App 信息…';
  static const String appInfoReadFailed = 'App 信息读取失败';
  static const String streamServiceTitle = 'StreamProvider + 插件隔离';
  static const String streamServiceDescription =
      'ViewModel 只认识 NetworkStatus，不依赖 connectivity_plus。';
  static const String checkingNetwork = '正在检查网络…';
  static const String networkListenFailed = '网络状态监听失败';
  static const String reloadAppInfo = '重新读取 App 信息';
  static const String noLoggedUser = '当前没有登录用户';
  static const String connectionWifi = 'Wi-Fi';
  static const String connectionMobile = '移动网络';
  static const String connectionEthernet = '有线网络';
  static const String connectionBluetooth = '蓝牙网络';
  static const String connectionSatellite = '卫星网络';
  static const String connectionVpn = 'VPN';
  static const String connectionOther = '其他网络';
  static const String connectionNone = '未连接';

  static String currentConnection(String type) =>
      '当前连接：$type\n连接状态来自 StreamProvider';

  // ==================== 操作类 ====================

  /// 登录按钮文案
  static const String login = '登录';

  /// 退出登录按钮文案
  static const String logout = '退出登录';

  /// 重试按钮文案
  static const String retry = '重试';

  /// 返回首页按钮文案
  static const String backHome = '返回首页';

  /// 切换主题按钮提示
  static const String switchTheme = '切换主题';

  // ==================== 表单类 ====================

  /// 账号输入框标签
  static const String account = '手机号/邮箱';

  /// 密码输入框标签
  static const String password = '密码';

  /// 表单校验提示：账号或密码为空
  static const String enterAccountAndPassword = '请输入账号和密码';

  // ==================== 状态提示类 ====================

  /// 无数据时提示
  static const String noData = '暂无数据';

  /// 页面不存在（404）提示
  static const String pageNotFound = '页面不存在';

  // ==================== 错误提示类 ====================

  /// 请求超时提示
  static const String requestTimeout = '请求超时，请稍后重试';

  /// 请求已取消提示
  static const String requestCanceled = '请求已取消';

  /// 网络连接异常提示
  static const String networkError = '网络连接异常';

  /// 证书校验失败提示
  static const String certificateError = '证书校验失败';

  /// 未知错误提示
  static const String unknownError = '未知错误，请稍后重试';

  /// 服务器异常提示
  static const String serverError = '服务器异常，请稍后重试';

  /// 通用请求失败提示
  static const String requestFailed = '请求失败，请稍后重试';

  /// 用户信息缺失提示
  static const String userMissing = '用户信息不存在，请重新登录';

  // ==================== Mock 数据提示 ====================

  /// 首页 Banner 模拟数据提示
  static const String mockBannerTips = '模拟接口数据，可替换为真实 Banner 图片和跳转';
}
