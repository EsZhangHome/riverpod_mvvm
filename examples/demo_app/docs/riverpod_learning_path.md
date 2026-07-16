# Riverpod 实战学习路径

这份文档是项目的代码阅读地图。三个根 Tab 按照业务复杂度组成一条连续路线：

运行 App 后，从“我的”页面右上角的学士帽按钮进入独立学习中心。商品、订单、
我的三个业务 Tab 不展示学习说明，保持原有业务页面结构。

```text
基础：商品与购物车
  → 异步：订单中心
  → 全局：我的与设置
```

每一站都按同一个顺序学习：

```text
业务场景
  → 为什么选择这些 Riverpod API
  → Model / Repository / ViewModel / View 数据流
  → 在 UI 中完成操作
  → 回到 ViewModel 和测试验证理解
```

不要从 Provider 声明开始死记 API。先操作页面并明确业务问题，再去代码里观察状态由谁拥有、由谁修改、何时释放。

## 学习中心本身如何实现

学习中心不是写死在“我的”页面中的大段文字，而是一个独立 MVVM 模块：

```text
RiverpodLesson / RiverpodCodeExample（Model）
  → LocalRiverpodLearningRepository（Repository）
  → riverpodLessonsProvider
  + riverpodLessonStageProvider（ViewModel）
  → currentRiverpodLessonProvider（派生状态）
  → RiverpodLearningPage（View）
```

建议先使用学习中心理解三站内容，完成后再阅读它自身的实现：

1. `lib/features/learning/model/riverpod_lesson.dart`
2. `lib/features/learning/repository/riverpod_learning_repository.dart`
3. `lib/features/learning/view_model/riverpod_learning_view_model.dart`
4. `lib/features/learning/view/riverpod_learning_page.dart`
5. `test/features/learning/riverpod_learning_view_model_test.dart`
6. `test/features/learning/riverpod_learning_page_test.dart`

当前课程来自本地 Repository，未来可以替换为 JSON、Markdown 或远端配置；当前阶段属于页面阅读状态，所以使用 `autoDispose`，离开学习中心后不占用会话状态。

## 第一站：基础——商品与购物车

### 场景

本地商品目录支持搜索、分类、收藏、加购、购物车详情、单项增减、移除、确认清空和金额汇总。这一站的数据都是同步的，适合先理解 Provider 之间如何拆分和组合。

### API

| API | 在当前场景中的职责 | 代码位置 |
| --- | --- | --- |
| `Provider` | 注入 `ProductRepository`，暴露只读商品集合 | `catalog_view_model.dart` |
| `NotifierProvider` | 管理筛选、收藏、购物车等可修改状态 | `catalog_view_model.dart` |
| 派生 `Provider` | 从商品、筛选和购物车计算可见列表、明细与汇总，不保存重复状态 | `visibleProductsProvider`、`cartLineItemsProvider`、`cartSummaryProvider` |
| `.family` | 按商品 id 隔离每张商品卡的购物车数量 | `cartQuantityProvider` |
| `ref.watch` | View 订阅构建所需状态 | `home_page.dart` |
| `ref.read` | 点击按钮时调用 Notifier 命令，不建立订阅 | `home_page.dart` |
| `ref.listen` | 监听加购结果并展示 SnackBar 副作用 | `home_page.dart` |
| `select` | 只监听收藏结果、商品数量或购物车总数 | `home_page.dart` |

### 数据流

```text
LocalProductRepository
  → productRepositoryProvider
  → productsProvider
  → catalogFilterProvider / favoriteProductIdsProvider / cartProvider
  → visibleProductsProvider / cartQuantityProvider / cartLineItemsProvider / cartSummaryProvider
  → HomePage / ProductCard / CartPage
```

Model 是纯 Dart 数据；Repository 提供数据；ViewModel 中的 Provider 持有或派生状态；View 只订阅状态和发送命令。

### 可操作 UI

1. 输入搜索词或选择分类，观察 `watch` 如何刷新商品列表。
2. 收藏商品，再打开“只看收藏”，观察派生 Provider 如何组合多个来源。
3. 给不同商品加购，观察 `.family + select` 如何让单个卡片只关注自己的数量。
4. 观察加购 SnackBar：这是 `listen` 处理副作用，而不是 ViewModel 持有 `BuildContext`。
5. 点击首页右上角购物车，确认跳转后仍显示刚才加入的商品；路由跳转不会清空 `cartProvider`。
6. 在购物车详情中增减、移除商品，观察 `cartLineItemsProvider` 和 `cartSummaryProvider` 从同一源状态实时派生。
7. 点击清空购物车并确认，观察明细和汇总同时进入空状态；取消确认时状态保持不变。

购物车当前只保存在登录会话内存中：进入详情、返回或切换 Tab 会保留；退出登录、切换用户或 App 进程重启会清空。生产项目需要跨进程恢复时，应通过 Repository 接入数据库或本地存储。

### 推荐阅读顺序

1. `lib/features/home/model/product.dart`
2. `lib/features/home/repository/product_repository.dart`
3. `lib/features/home/view_model/catalog_view_model.dart`
4. `lib/features/home/view/home_page.dart`
5. `lib/features/home/view/cart_page.dart`
6. `test/features/home/catalog_providers_test.dart`
7. `test/features/home/cart_page_test.dart`

## 第二站：异步——订单中心

### 场景

订单包含首屏加载、下拉刷新、分页、创建、取消、详情查询和物流推送。这里同时存在网络等待、局部操作、并发结果、错误恢复和页面销毁。

### API

| API | 在当前场景中的职责 | 代码位置 |
| --- | --- | --- |
| `AsyncNotifierProvider` | 管理订单初载、分页、创建和乐观取消命令 | `orderFeedProvider` |
| `AsyncValue` | 统一表达首屏 `loading / error / data` | `OrdersPage` |
| `NotifierProvider` | 管理同步订单筛选 | `orderFilterProvider` |
| `FutureProvider.autoDispose.family` | 按订单 id 查询详情，并在成功后做 TTL 缓存 | `orderDetailProvider` |
| `StreamProvider.autoDispose.family` | 按订单 id 订阅实时物流状态 | `orderStatusProvider` |
| `ref.refresh` | 下拉刷新并等待新的 Future 完成 | `RefreshIndicator` |
| `ref.invalidate` | 销毁当前状态；有活动监听时随后重建，无监听时等下次读取再创建 | `OrdersPage`、`OrderFeedNotifier` |
| `retry` | 只为可能恢复的首屏网络异常执行有限重试 | `orderFeedProvider` |
| `keepAlive` | 详情成功后短期复用结果 | `orderDetailProvider` |
| `onCancel/onResume/onDispose` | 管理 TTL、Stream 订阅和请求释放边界 | `orderDetailProvider` |

### 数据流

```text
OrderRepository
  → orderRepositoryProvider
  → OrderFeedNotifier
  → AsyncValue<OrderFeedState>
  → visibleOrdersProvider
  → OrdersPage

订单 id
  → orderDetailProvider(id) / orderStatusProvider(id)
  → 详情弹窗
  → 实时状态再同步回订单列表
```

异步命令在 `await` 后重新读取最新 State，防止分页和创建并发时旧快照覆盖新结果。取消订单先乐观更新；接口失败时回滚，并合并取消期间收到的最新远端物流状态。

### 可操作 UI

1. 首次进入页面，观察 `AsyncValue.when` 的三态渲染。
2. 下拉刷新，对照 `ref.refresh(orderFeedProvider.future)`。
3. 加载下一页，观察旧列表保留，仅底部按钮进入 loading。
4. 创建订单，观察命令状态与首屏加载状态为什么需要分开。
5. 取消订单，观察乐观更新和失败回滚的数据流。
6. 打开订单详情，观察 `family` 如何按 id 隔离缓存和物流 Stream。
7. 在详情请求未完成时关闭弹窗，观察 `CancelToken` 随 Provider 生命周期取消。

### 推荐阅读顺序

1. `lib/features/orders/model/order.dart`
2. `lib/features/orders/repository/order_repository.dart`
3. `lib/features/orders/view_model/order_view_model.dart`
4. `lib/features/orders/view/orders_page.dart`
5. `test/features/orders/order_providers_test.dart`

## 第三站：全局——我的与设置

### 场景

登录会话和主题需要跨路由、跨 Tab 共享；App 信息和网络监听来自平台插件，需要通过服务接口隔离；用户切换后，用户级购物车和订单又必须自动清理。

### API

| API | 在当前场景中的职责 | 代码位置 |
| --- | --- | --- |
| App 级 `NotifierProvider` | 管理登录会话与主题状态 | `authProvider`、`themeProvider` |
| Service `Provider` | 注入网络、App 信息、存储和 API 服务 | 企业底座 `lib/core/providers/service_providers.dart` |
| `FutureProvider.autoDispose` | 把一次性 App 信息查询转换为 `AsyncValue` | `appInfoProvider` |
| `StreamProvider.autoDispose` | 把插件网络事件转换为页面状态 | `networkStatusProvider` |
| `select` | 页面只订阅用户或 `themeMode` 等最小切片 | `MinePage` |
| `override` | 测试时替换平台服务，不启动真实插件 | `global_service_providers_test.dart` |
| Provider 依赖关系 | 用户 id 变化后重建购物车、收藏和订单作用域 | `currentUserIdProvider` |

### 数据流

```text
Storage / ApiClient / Platform Service
  → Service Provider
  → App 级 Notifier 或页面 Future/Stream Provider
  → MaterialApp / GoRouter / MinePage

authProvider.currentUser.id
  → currentUserIdProvider
  → 商品用户级状态与订单 Repository
  → 退出或切换账号时自动重建
```

全局不等于所有东西都永不释放。登录态和主题属于 App 生命周期；订单详情、App 信息和网络页面订阅属于消费页面生命周期；购物车和订单列表属于“当前用户会话 + 根 Tab”生命周期。

### 可操作 UI

1. 切换主题，观察 `themeProvider` 如何让整个 `MaterialApp` 更新并持久化。
2. 查看 App 信息，观察 Service Provider 和 `FutureProvider` 的职责分离。
3. 切换网络环境，观察 `StreamProvider` 连续推送状态。
4. 点击重新读取 App 信息，对照 `ref.invalidate(appInfoProvider)`。
5. 退出登录，观察 GoRouter 重定向，以及用户级 Provider 状态的生命周期边界。

### 推荐阅读顺序

1. 企业底座 `lib/core/providers/service_providers.dart`
2. 企业底座 `lib/features/auth/auth_providers.dart`
3. 企业底座 `lib/shared/theme/theme_provider.dart`
4. Demo `lib/features/mine/view_model/mine_view_model.dart`
5. Demo `lib/features/mine/view/mine_page.dart`
6. Demo `test/features/mine/mine_service_providers_test.dart`

## Provider 生命周期选择

| 状态范围 | 例子 | 选择 |
| --- | --- | --- |
| App 生命周期 | 登录态、主题 | 非 `autoDispose` 的 App 级 Provider |
| 当前用户会话 | 收藏、购物车、订单仓库 | 依赖 `currentUserIdProvider`，用户变化时重建 |
| 根 Tab | 商品筛选、已加载订单分页 | 非 `autoDispose`，切换 Tab 后保留 |
| 页面或弹窗 | 学习阶段、购物车派生明细、订单详情、物流流、App 信息 | `autoDispose` |
| 成功后短期缓存 | 订单详情 | `autoDispose + keepAlive + TTL` |
| 正在执行的网络请求 | 初载、分页、创建、取消、详情 | `CancelToken + ref.onDispose + ref.mounted` |

## MVVM 检查清单

阅读或新增功能时，可以用下面的问题检查代码边界：

- Model 是否保持不可变、纯 Dart，不导入 Flutter 或 Riverpod？
- Repository 是否只负责数据来源、序列化和请求取消？
- ViewModel 是否负责状态、业务命令、并发合并和错误策略？
- View 是否只做 `watch/listen`、渲染和 `read` 命令？
- 派生数据是否通过 Provider 计算，而不是再保存一份可变 State？
- Provider 的生命周期是否由业务范围决定，而不是机械地全部加 `autoDispose`？
- 测试是否可以通过 Provider `override` 替换 Repository 或 Service？

完成三站后，再阅读项目中的登录、路由守卫、通用网络请求和现有测试，就能把相同模式迁移到真实业务模块。
