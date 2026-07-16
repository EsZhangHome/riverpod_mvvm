# Riverpod MVVM Flutter 架构说明

这是一个面向中型 Flutter 项目的可复用基础架构。项目核心技术栈：

- Flutter
- Riverpod
- MVVM
- Repository
- Dio
- GoRouter
- sqflite
- json_serializable
- cached_network_image
- connectivity_plus
- permission_handler
- package_info_plus
- shared_preferences
- flutter_secure_storage

项目当前只保留 Android 和 iOS 平台目录，适合作为移动端业务 App 的基础工程。

当前项目已升级到 Flutter 3.44 稳定版，SDK 约束为：

- Dart SDK：`>=3.12.0 <4.0.0`
- Flutter SDK：`>=3.44.0`

Android 构建配置已迁移到 Gradle Kotlin DSL；iOS 插件集成已迁移到 Flutter 生成的 Swift Package Manager，不再保留 CocoaPods / Podfile。

## 快速开始与推荐阅读顺序

第一次拉取项目后执行：

```bash
flutter pub get
flutter run
```

默认开启本地 Mock，不需要后端即可登录和体验全部示例。登录页已预填 `user@example.com / 123456`；账号和密码只要非空即可走 Mock 登录。

如果目标是快速读懂代码，建议不要先顺序通读整份长文档，而是按下面的路径阅读：

| 顺序 | 先解决的问题 | 推荐入口 |
| --- | --- | --- |
| 1 | App 如何启动、ProviderScope 放在哪里 | [main.dart](lib/main.dart) → [app.dart](lib/app/app.dart) |
| 2 | 登录态如何恢复并驱动路由 | [auth_view_model.dart](lib/features/auth/view_model/auth_view_model.dart) → [route_guard.dart](lib/app/navigation/route_guard.dart) → [app_router.dart](lib/app/navigation/app_router.dart) |
| 3 | 同步业务状态、派生状态和局部监听怎么写 | [catalog_view_model.dart](lib/features/home/view_model/catalog_view_model.dart) → [home_page.dart](lib/features/home/view/home_page.dart) → [cart_page.dart](lib/features/home/view/cart_page.dart) |
| 4 | AsyncNotifier、family、刷新、缓存和 Stream 怎么组合 | [order_view_model.dart](lib/features/orders/view_model/order_view_model.dart) → [orders_page.dart](lib/features/orders/view/orders_page.dart) |
| 5 | 请求取消和页面生命周期如何闭环 | [async_request_handler.dart](lib/shared/state/async_request_handler.dart) → [home_view_model.dart](lib/features/home/view_model/home_view_model.dart) → [生命周期测试](test/features/home/home_provider_lifecycle_test.dart) |
| 6 | App 级 Provider 和平台 Service 如何注入 | [mine_view_model.dart](lib/features/mine/view_model/mine_view_model.dart) → [mine_page.dart](lib/features/mine/view/mine_page.dart) |
| 7 | 模块边界如何被自动约束 | [dependency_rules_test.dart](test/architecture/dependency_rules_test.dart) |

需要按 Riverpod API 从基础到全局学习时，使用 [Riverpod 实战学习路径](docs/riverpod_learning_path.md)，或在 App“我的”页面右上角进入学习中心。

日常开发最常用的三个命令：

```bash
dart run build_runner build  # 修改 json_serializable Model 后执行
flutter analyze
flutter test
```

## 0. 大纲导航

- [0.1 当前依赖库说明](#01-当前依赖库说明)
- [0.2 当前开发环境和平台配置](#02-当前开发环境和平台配置)
- [0.3 Riverpod 3 约定](#03-riverpod-3-约定)
- [0.4 实战学习路径](#04-实战学习路径)
- [1. 项目整体分层](#1-项目整体分层)
- [2. 启动流程](#2-启动流程)
- [3. 核心目录说明](#3-核心目录说明)
  - [3.1 shared/state、shared/ui 与 core/cache](#31-sharedstate-sharedui-与-corecache)
  - [3.2 core/config](#32-coreconfig)
  - [3.3 core/database](#33-coredatabase)
  - [3.4 core/network](#34-corenetwork)
  - [3.5 core/permission](#35-corepermission)
  - [3.6 core/app](#36-coreapp)
  - [3.7 app/navigation 与 shared/navigation](#37-appnavigation-与-sharednavigation)
  - [3.8 core/storage](#38-corestorage)
  - [3.9 core/providers](#39-coreproviders)
  - [3.10 shared/localization](#310-sharedlocalization)
  - [3.11 shared/theme](#311-sharedtheme)
  - [3.12 core/utils](#312-coreutils)
- [4. App 级状态的归属](#4-app-级状态的归属)
- [5. shared 层](#5-shared-层)
- [6. features 业务模块](#6-features-业务模块)
- [7. MVVM + Repository 数据流](#7-mvvm--repository-数据流)
- [8. 新增业务模块应该怎么做](#8-新增业务模块应该怎么做)
- [9. 接入真实后端需要改哪里](#9-接入真实后端需要改哪里)
- [10. 如何编写单元测试](#10-如何编写单元测试)
- [11. 工程工具和常用命令](#11-工程工具和常用命令)
- [12. 架构设计哲学](#12-架构设计哲学)
  - [12.1 组合优于继承](#121-组合优于继承为什么-asyncrequesthandler-是工具类而不是基类)
  - [12.2 回调注入](#122-回调注入打破-apiclient-和-authprovider-之间的循环依赖)
  - [12.3 401 并发保护](#123-401-并发保护unauthorizedguard)
  - [12.4 StatefulShellRoute](#124-statefulshellroute消除一整个-viewmodel)
  - [12.5 不可变状态](#125-不可变状态riverpod-的脏检查优化)
  - [12.6 拦截器链顺序](#126-拦截器链的顺序有讲究)
  - [12.7 测试边界](#127-测试边界就是架构边界)
  - [12.8 Mock 开关](#128-mock-开关是编译时优化不是运行时判断)
  - [12.9 ViewState 状态机](#129-viewstate-不是五个值是一个状态机)
  - [12.10 模型所有权与公共入口](#1210-模型所有权与公共入口)
- [13. 开发约定](#13-开发约定)
- [14. 一句话理解这个架构](#14-一句话理解这个架构)

## 0.1 当前依赖库说明

| 库 | 类型 | 主要功能 | 项目中的使用位置 / 封装 |
| --- | --- | --- | --- |
| `flutter_riverpod` `3.3.2` | 运行依赖 | 状态管理 + 依赖注入，替代 Provider + get_it | `main.dart` 中通过 `ProviderScope` 提供；各层通过 `ref.watch/read` 获取 |
| `dio` | 运行依赖 | HTTP 请求、拦截器、超时、取消请求、上传下载 | `core/network/api_client.dart`，业务层只依赖 `ApiService` |
| `go_router` | 运行依赖 | 声明式路由、StatefulShellRoute Tab 管理、登录拦截 | `app/navigation/app_router.dart`、`shared/navigation/route_paths.dart` |
| `sqflite` | 运行依赖 | Android / iOS 本地 SQLite 数据库 | `core/database`，业务层只依赖 `DatabaseService` |
| `path` | 运行依赖 | 拼接数据库文件路径 | `core/database/app_database.dart` |
| `shared_preferences` | 运行依赖 | 保存轻量配置，如主题模式、普通字符串 | `core/storage/local_storage.dart` |
| `flutter_secure_storage` | 运行依赖 | 安全保存 token 等敏感数据 | `core/storage/token_storage.dart` |
| `json_annotation` | 运行依赖 | 给 Model 标注 JSON 生成规则 | `UserModel`、`HomeBanner`、`LoginRequest` 等 Model |
| `json_serializable` | 开发依赖 | 生成 `fromJson / toJson` 代码 | 配合 `build_runner` 生成 `*.g.dart` |
| `build_runner` | 开发依赖 | Dart 代码生成命令行工具 | 执行 `dart run build_runner build` |
| `cached_network_image` | 运行依赖 | 网络图片缓存、加载占位、失败占位 | `shared/ui/app_network_image.dart` |
| `connectivity_plus` | 运行依赖 | 获取网络连接状态 | `core/network/network_status_service.dart`，业务层只依赖 `NetworkStatusService` |
| `permission_handler` | 运行依赖 | 申请相机、相册、定位、通知等权限 | `core/permission/permission_service.dart` |
| `package_info_plus` | 运行依赖 | 获取 App 名称、包名、版本号、构建号 | `core/app/app_info_service.dart` |
| `flutter_localizations` | SDK 依赖 | Flutter 官方本地化支持 | `app/app.dart` 中配置中文本地化 |
| `intl` | 运行依赖 | 国际化、日期数字格式化基础库 | 当前配合本地化能力预留 |
| `cupertino_icons` | 运行依赖 | iOS 风格图标字体 | Flutter 默认图标依赖 |
| `flutter_native_splash` | 开发依赖 | 生成 Android / iOS 原生启动图 | README 中提供配置步骤，当前未生成假素材 |
| `flutter_launcher_icons` | 开发依赖 | 生成 Android / iOS App 图标 | README 中提供配置步骤，当前未生成假素材 |
| `flutter_lints` | 开发依赖 | Flutter 官方推荐 lint 规则 | `analysis_options.yaml` |

使用原则：

- 业务页面不要直接依赖 `dio`、`sqflite`、`permission_handler`、`connectivity_plus` 等三方库。
- 三方能力优先封装到 `core/` 或 `shared/`，再通过接口或通用组件给业务模块使用。
- 新增库时同步补 README，说明它解决什么问题、封装在哪里、业务层应该怎么用。

## 0.2 当前开发环境和平台配置

推荐开发环境：

| 工具 | 版本 / 要求 |
| --- | --- |
| Flutter | `3.44.x stable` |
| Dart | `3.12.x` |
| Xcode | `26.5` 或更新版本 |
| Android SDK | `36` |
| Java | `17` 或更新版本 |

平台配置说明：

- Android 使用 Kotlin DSL：`android/settings.gradle.kts`、`android/build.gradle.kts`、`android/app/build.gradle.kts`。
- Android Gradle Plugin 使用 Flutter 3.44 模板配置，Gradle wrapper 使用 `9.1.0`。
- iOS 插件依赖通过 Flutter 生成的 Swift Package Manager 接入。
- iOS 不再使用 CocoaPods，仓库中不保留 `ios/Podfile` 和 `ios/Podfile.lock`。
- iOS 最低部署目标为 `13.0`。

常用验证命令：

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

## 0.3 Riverpod 3 约定

项目使用 `flutter_riverpod 3.3.2`，开发时遵守以下约定：

- 同步状态继承 `Notifier<State>`，异步初始化状态继承 `AsyncNotifier<State>`；是否自动释放由 `NotifierProvider.autoDispose` / `AsyncNotifierProvider.autoDispose` 声明，不再使用 Riverpod 2 的 `AutoDisposeNotifier` 接口。
- Provider 初始化抛出异常时，Riverpod 3 默认会重试。订单首屏通过 `AsyncNotifierProvider(retry: ...)` 明确限制次数；使用 `AsyncRequestHandler` + Dio 重试的请求则不再叠加 Provider 自动重试，避免同一请求被两层重复执行。
- 异步操作完成后使用 `ref.mounted` 检查生命周期；请求层同时通过 `CancelToken` 和 Handler 的 disposed 状态丢弃失效结果。
- Riverpod 3 使用 `==` 过滤状态通知；State 保持不可变并通过 `copyWith` 创建新对象。
- `StateProvider`、`StateNotifierProvider`、`ChangeNotifierProvider` 已属于 legacy API；新增业务状态优先使用 `NotifierProvider` 或 `AsyncNotifierProvider`。
- 不可见 Widget 的监听可能被 Riverpod 暂停。需要持续运行的 App 级任务应放在明确的全局 Provider 中，不依赖某个不可见页面维持监听。

## 0.4 实战学习路径

> 如果目标是边运行 App、边按代码顺序学习，请直接阅读独立的
> [Riverpod 实战学习路径](docs/riverpod_learning_path.md)。运行 App 后，可从“我的”
> 页面右上角的学习入口打开独立学习中心；业务 Tab 本身保持专注于业务操作。

三个根 Tab 组成一条连续业务链，不把 API 拆成互不相关的计数器：

```text
商品目录与购物车（同步状态）
  -> 创建和管理订单（异步状态）
  -> 登录、主题和设备服务（全局状态）
```

建议按下面顺序阅读：

| 阶段 | 业务问题 | Riverpod 重点 | 入口 |
| --- | --- | --- | --- |
| 1. 商品 | 搜索、分类、收藏、购物车明细、汇总 | `Provider`、`NotifierProvider`、派生 Provider、`family`、`select`、`watch/read/listen` | `features/home` |
| 2. 订单 | 初载、刷新、分页、创建、乐观取消、详情缓存、实时物流 | `AsyncNotifierProvider`、`FutureProvider.family`、`StreamProvider.family`、`AsyncValue`、`retry`、`refresh/invalidate`、`keepAlive` | `features/orders` |
| 3. 我的 | 登录态驱动路由、主题持久化、App 信息、网络状态 | App 级 Provider、Service Provider、`FutureProvider`、`StreamProvider`、依赖 override | `features/mine`、`features/auth`、`shared/theme`、`core/providers` |
| 4. 网络生命周期 | 页面销毁时取消 Dio 请求、丢弃过期结果 | `autoDispose`、`ref.onDispose`、`ref.mounted`、`CancelToken` | `features/home/view_model/home_view_model.dart`、`features/orders`、`shared/state/async_request_handler.dart` |

Provider 的生命周期按业务选择，而不是全部加 `autoDispose`：

- 商品筛选、购物车、订单列表是根 Tab 状态，切换 Tab 后应保留，因此使用非 auto-dispose Provider；它们同时依赖 `currentUserIdProvider`，退出或切换账号时会重建，避免跨账号残留。
- 购物车当前是“登录会话内的内存状态”：进入详情、返回商品页或切换 Tab 不会清空；退出登录、切换用户或 App 进程重启会清空。需要跨进程保留时，应在 Repository 中接入数据库或本地存储，而不是让 View 直接持久化。
- 订单详情、实时物流、App 信息等页面消费状态使用 `autoDispose`。
- 学习中心的当前阅读阶段只属于页面会话，离开页面后由 `NotifierProvider.autoDispose` 释放；课程内容由可替换的 Repository Provider 提供。
- 订单详情只有请求成功后才通过 `keepAlive + onCancel/onResume` 缓存 30 秒；请求尚未完成时关闭弹窗会立即取消，不缓存 loading/error。
- Dio 请求通过 `AsyncRequestHandler` 或 Provider 自己持有 `CancelToken`，在 `ref.onDispose` 时触发 `cancel()`。

开发新功能时可以直接按职责选型：

| 需求 | 推荐 API | 当前示例 |
| --- | --- | --- |
| 注入 Repository/Service，或同步只读计算 | `Provider` | `productRepositoryProvider`、`cartSummaryProvider`、`riverpodLessonsProvider` |
| 同步状态 + 修改命令 | `NotifierProvider` | 搜索筛选、收藏、购物车、主题、登录态 |
| 首次异步加载 + 多个业务命令 | `AsyncNotifierProvider` | 订单初载、分页、创建、取消 |
| 单次、只读异步查询 | `FutureProvider` | App 信息、订单详情 |
| 连续事件 | `StreamProvider` | 网络连接、订单实时状态 |
| 同一种状态按 id/参数隔离 | `.family` | 单商品数量、订单详情、订单物流 |
| 最后一个监听离开就释放 | `.autoDispose` | 购物车派生明细、学习阶段、弹窗详情、实时流、页面服务状态 |
| 成功结果短期复用 | `ref.keepAlive()` + TTL | 订单详情 30 秒缓存 |
| Widget 只关心 State 的一小部分 | `select` | 主题模式、单商品收藏/数量 |
| 一次性 UI 副作用 | `ref.listen` | 加购/订单操作 SnackBar、路由刷新桥接 |

不要因为某个 API 尚未出现就硬塞进业务。Provider 类型由数据所有权、是否异步、是否可修改和生命周期共同决定；能用派生 `Provider` 计算的值，不要再保存一份可变 State。

本项目刻意不使用 Riverpod 3 的 legacy `StateProvider`、`StateNotifierProvider` 和 `ChangeNotifierProvider`。代码生成不是理解 MVVM 数据流的前提，所以教学代码先使用手写 Provider；业务扩大后可再引入 `riverpod_generator` 减少声明样板。

### 当前示例的数据来源与持久化边界

| 功能 | 当前数据来源 | 保留范围 |
| --- | --- | --- |
| 商品目录 | `LocalProductRepository` 固定商品 | Repository 实例生命周期 |
| 搜索、收藏、购物车 | Riverpod 内存 State | 当前登录用户会话；不跨 App 进程 |
| 订单列表、详情、物流 | `MockOrderRepository` | 当前登录用户会话；详情成功后额外缓存 30 秒 |
| 登录 Token | `flutter_secure_storage` | 跨 App 进程安全保存 |
| 当前用户资料、主题 | `shared_preferences` | 跨 App 进程保存 |
| App 信息、网络状态 | 平台 Service | 跟随页面订阅，离开后自动释放 |
| 学习课程 | `LocalRiverpodLearningRepository` | 课程为本地只读数据；当前阶段跟随学习页面释放 |

Mock、内存状态和真实平台服务被明确区分，避免把教学示例中的生命周期误认为生产数据持久化策略。

## 1. 项目整体分层

项目采用模块化单体（modular monolith）：仍是一个 Flutter Package，但用明确的目录所有权和公开入口隔离模块。

```text
lib/
  main.dart                    # 初始化基础设施并创建 ProviderScope
  app/
    app.dart                   # MaterialApp、主题、路由组装
    navigation/               # GoRouter、MainShell、路由守卫和 404 页面

  core/                       # 不知道任何业务页面
    app/                      # AppInfo 等平台能力
    cache/                    # CachePolicy
    config/                   # 编译期环境配置
    database/                 # SQLite 抽象与实现
    network/                  # Dio、ApiService、异常和拦截器
    permission/               # 权限插件隔离
    providers/                # 仅基础设施 Service Provider
    storage/                  # 普通存储与安全 Token 存储
    utils/                    # 日志、崩溃入口、JSON 工具

  shared/                     # 没有业务所有权的跨模块复用能力
    localization/             # AppStrings
    navigation/               # RoutePaths
    state/                    # ViewState、请求与分页处理器
    theme/                    # Theme、Spacing、Radius、主题 Provider
    ui/                       # PageShell、StateView、通用 Widget

  features/
    auth/                     # 登录、会话、UserModel；auth.dart 是公共入口
    home/                     # 商品、收藏、购物车、Banner
    orders/                   # AsyncNotifier 订单实战
    mine/                     # App 级状态和平台 Service 场景
    learning/                 # 基础 → 异步 → 全局学习中心
    profile/                  # 保留的独立资料页能力
```

每一层的职责非常明确：

- `app/`：只负责应用组装与导航，可依赖所有模块，但通过各 feature 的公共入口访问。
- `core/`：和具体业务、UI 无关，只能依赖 core 内部及三方基础库。
- `shared/`：多个业务复用且没有领域所有权的能力，可依赖 core，不能依赖 feature/app。
- `features/`：具体业务功能，每个模块维护自己的 Model、Repository、Provider、ViewModel 和 View。

依赖方向固定为：

```text
app -> features -> shared -> core
              \------------> core
```

跨业务依赖必须经过被依赖模块的公共入口。例如 Home、Orders、Mine 需要登录用户时统一导入 `features/auth/auth.dart`，不直接引用 Auth 内部文件。`test/architecture/dependency_rules_test.dart` 会自动检查这些规则。

| 当前文件属于 | 可以依赖 | 不可以依赖 |
| --- | --- | --- |
| `core` | core 内部、基础三方库 | shared、feature、app |
| `shared` | core、shared 内部 | feature、app |
| `features/<name>` | core、shared、本模块内部 | app、其他 feature 的内部文件 |
| `app` | 所有层；访问 feature 时走 `<feature>.dart` | feature 的 model/view/view_model 内部路径 |

Provider 也按所有权放置：

| Provider 类型 | 放置位置 | 当前示例 |
| --- | --- | --- |
| Dio、数据库、权限等基础服务 | `core/providers/service_providers.dart` | `apiServiceProvider` |
| Repository 注入 | 拥有该 Repository 的 feature | `home_providers.dart`、`auth_providers.dart` |
| 页面或业务状态 | 对应 feature 的 `view_model` | `cartProvider`、`orderFeedProvider` |
| 有明确领域的 App 级状态 | 领域 feature | `features/auth` 中的 `authProvider` |
| 无业务归属的 App 级外观状态 | shared | `shared/theme` 中的 `themeProvider` |

推荐后续开发继续沿用这个结构，不要把业务代码直接堆到 `main.dart`、`app.dart` 或 `core/` 中。

## 2. 启动流程

入口文件是 [lib/main.dart](lib/main.dart)。

启动顺序：

1. 注册全局异常兜底。
2. 调用 `WidgetsFlutterBinding.ensureInitialized()`。
3. 初始化本地存储 `LocalStorage.init()`。
4. 初始化本地数据库 `AppDatabase.init()`。
5. 执行 `runApp(const ProviderScope(child: MyApp()))`。

简化流程如下：

```text
main()
  -> FlutterError / PlatformDispatcher 异常兜底
  -> LocalStorage.init()
  -> AppDatabase.init()
  -> runApp(ProviderScope(child: MyApp))
```

[lib/app/app.dart](lib/app/app.dart) 负责组装 App 外壳：

- 使用 `ProviderScope` 作为 Riverpod 根节点（在 main.dart 中提供）。
- `_AppViewState`（ConsumerStatefulWidget）通过 `ref.listen(authProvider)` 桥接 GoRouter 的 `refreshListenable`。
- 使用 `MaterialApp.router` 接入 GoRouter。
- 通过 `ref.watch(themeProvider)` 接入 light/dark 主题。
- 接入基础本地化配置。

注意：`GoRouter` 实例在 `_AppViewState` 中只创建一次，避免 App rebuild 时重复创建路由对象。

## 3. 核心目录说明

### 3.1 shared/state、shared/ui 与 core/cache

路径：[lib/shared/state](lib/shared/state)、[lib/shared/ui](lib/shared/ui)、[lib/core/cache](lib/core/cache)

`shared/state` 放与具体业务无关的状态/请求协作工具，`shared/ui` 放通用展示外壳，缓存抽象则属于纯数据基础能力并留在 `core/cache`。拆开后 core 不再反向依赖 shared 的 UI 或文案。

#### AsyncRequestHandler

文件：[lib/shared/state/async_request_handler.dart](lib/shared/state/async_request_handler.dart)

`AsyncRequestHandler` 是 Notifier 中使用的异步请求工具类（替代旧的 `BaseViewModel extends ChangeNotifier`）。

它负责：

- 请求防抖，避免连续触发重复请求
- 内置 `CancelToken`，dispose 时自动取消所有请求
- Provider 销毁或请求取消后静默丢弃结果，不进入 error 状态
- 通过回调（`onLoading`/`onSuccess`/`onEmpty`/`onError`）委托状态切换给 Notifier

需要跟随页面释放的请求型 ViewModel 使用 `NotifierProvider.autoDispose`，在 `build()` 中创建一个 `AsyncRequestHandler` 实例，并通过 `ref.onDispose` 释放。根 Tab 等需要保留状态的 ViewModel 不应机械套用本规则。Riverpod 3 的页面生命周期、请求取消链路如下：

```text
页面最后一个监听者消失
  -> NotifierProvider.autoDispose 销毁 ViewModel
  -> ref.onDispose
  -> AsyncRequestHandler.dispose
  -> CancelToken.cancel
  -> Dio 中止请求
  -> 取消结果被静默丢弃，不再回写页面状态
```

异步请求返回后，ViewModel 还会检查 `ref.mounted`，避免操作已经销毁的 Ref/Notifier。

使用方式示例：

```dart
final data = await _handler.execute<List<Item>>(
  request: () => ref.read(repoProvider).fetchData(cancelToken: _handler.cancelToken),
  onLoading: () => state = state.copyWith(viewState: ViewState.loading),
  onSuccess: () => state = state.copyWith(viewState: ViewState.success),
  onEmpty: () => state = state.copyWith(viewState: ViewState.empty),
  onError: (msg) => state = state.copyWith(viewState: ViewState.error, errorMessage: msg),
  isEmpty: (data) => data.isEmpty,
);
```

#### ViewState

页面状态定义在 [lib/shared/state/view_state.dart](lib/shared/state/view_state.dart)：

```dart
enum ViewState {
  idle,
  loading,
  success,
  empty,
  error,
}
```

#### PageShell

文件：[lib/shared/ui/page_shell.dart](lib/shared/ui/page_shell.dart)

`PageShell` 是精简的页面外壳，负责根据 `ViewState` 自动展示 loading / error / empty / content。首次加载时机仍由页面的 `initState` 或异步 Provider 自己管理，`PageShell` 不持有 ViewModel 生命周期。

页面使用 `ConsumerStatefulWidget` + `ref.watch(provider)` 获取 Notifier 状态，通过 `PageShell` 包装 `StateView`：

```dart
class MyPage extends ConsumerStatefulWidget { ... }

class _MyPageState extends ConsumerState<MyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(myProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProvider);
    return PageShell(
      viewState: state.viewState,
      errorMessage: state.errorMessage,
      onRetry: () => ref.read(myProvider.notifier).loadData(),
      builder: (context) => /* 正常内容 */,
    );
  }
}
```

#### PaginatedListHandler

文件：[lib/shared/state/paginated_handler.dart](lib/shared/state/paginated_handler.dart)

`PaginatedListHandler<T>` 是分页列表处理器，封装了下拉刷新（reset to page 1）和上拉加载更多（append next page）的通用逻辑。`fetchPage` 会强制收到处理器持有的 `CancelToken`，调用者必须继续透传给 Repository，确保 Notifier 销毁时真正中止网络请求。

使用 `PaginatedListState<T>` 作为 Notifier 的状态类，包含 `items`、`page`、`hasMore`、`isRefreshing`、`isLoadingMore` 等字段。

#### CachePolicy

文件：[lib/core/cache/cache_policy.dart](lib/core/cache/cache_policy.dart)

`CachePolicy<T>` 是 Repository 层缓存抽象。当前提供 `MemoryCachePolicy<T>`（内存缓存 + TTL 过期）。

### 3.2 core/config

路径：[lib/core/config/env_config.dart](lib/core/config/env_config.dart)

`EnvConfig` 负责环境配置，支持通过 `--dart-define` 覆盖默认值。

目前支持：

- `apiBaseUrl`
- `connectTimeout`
- `receiveTimeout`
- `sendTimeout`
- `retryCount`
- `enableCharlesProxy`
- `charlesProxyHost`
- `charlesProxyPort`
- `allowCharlesBadCertificate`
- `apiSuccessCode`
- `useHttpStatus`
- `isDebug`
- `enableMock`：是否使用 Mock 数据（默认 true，演示阶段；接真实后端时设为 false）

默认不传参数也能正常启动。

运行示例：

```bash
flutter run \
  --dart-define=ENV_API_BASE_URL=https://dev-api.example.com \
  --dart-define=ENV_RETRY_COUNT=3
```

#### Charles 抓包怎么用

项目已经把 Charles 代理开关接进了 `EnvConfig` 和 `ApiClient`。

默认情况下不会走 Charles，只有启动 App 时显式传入 `ENV_ENABLE_CHARLES_PROXY=true`，Dio 请求才会被转发到 Charles。

##### 1. 先确认 Charles 代理端口

打开 Charles：

1. 进入 `Proxy` -> `Proxy Settings...`
2. 确认 `HTTP Proxy` 已开启
3. 记住端口号，Charles 默认是 `8888`

如果你没有改过 Charles 配置，端口一般不用动。

##### 2. 确认 Flutter 要连接的代理地址

不同运行环境填写的 host 不一样：

| 运行环境 | `ENV_CHARLES_PROXY_HOST` 建议值 |
| --- | --- |
| iOS 模拟器 | `127.0.0.1` 或电脑局域网 IP |
| Android 模拟器 | `10.0.2.2` |
| iPhone / Android 真机 | 电脑在当前 Wi-Fi 下的局域网 IP |

电脑局域网 IP 可以在系统网络设置里查看。真机和电脑需要连同一个 Wi-Fi。

##### 3. 启动 App 时打开 Charles 代理

iOS 模拟器常用写法：

```bash
flutter run \
  --dart-define=ENV_ENABLE_CHARLES_PROXY=true \
  --dart-define=ENV_CHARLES_PROXY_HOST=127.0.0.1 \
  --dart-define=ENV_CHARLES_PROXY_PORT=8888
```

Android 模拟器常用写法：

```bash
flutter run \
  --dart-define=ENV_ENABLE_CHARLES_PROXY=true \
  --dart-define=ENV_CHARLES_PROXY_HOST=10.0.2.2 \
  --dart-define=ENV_CHARLES_PROXY_PORT=8888
```

真机常用写法，把 `192.168.1.10` 换成你自己电脑的局域网 IP：

```bash
flutter run \
  --dart-define=ENV_ENABLE_CHARLES_PROXY=true \
  --dart-define=ENV_CHARLES_PROXY_HOST=192.168.1.10 \
  --dart-define=ENV_CHARLES_PROXY_PORT=8888
```

##### 4. 在 Charles 中允许设备连接

第一次连接时，Charles 可能会弹出是否允许该设备访问代理。

选择 `Allow` 后，请求才会出现在 Charles 的会话列表里。

如果没有弹窗，可以检查：

- App 是否真的传了 `ENV_ENABLE_CHARLES_PROXY=true`
- host 是否填对
- Charles 的 `Proxy` -> `macOS Proxy` 不影响这里，项目使用的是 Dio 自己的代理配置
- 手机和电脑是否在同一个网络

##### 5. 抓 HTTPS 接口

如果接口是 HTTPS，通常还需要安装并信任 Charles 根证书：

1. 在 Charles 中进入 `Help` -> `SSL Proxying` -> `Install Charles Root Certificate`
2. 按 Charles 提示安装证书
3. 在设备或模拟器中信任该证书
4. 在 Charles 中进入 `Proxy` -> `SSL Proxying Settings...`
5. 添加需要抓包的域名，比如 `api.example.com:443`

如果只是临时调试证书问题，也可以打开证书跳过开关：

```bash
flutter run \
  --dart-define=ENV_ENABLE_CHARLES_PROXY=true \
  --dart-define=ENV_CHARLES_PROXY_HOST=127.0.0.1 \
  --dart-define=ENV_CHARLES_PROXY_PORT=8888 \
  --dart-define=ENV_ALLOW_CHARLES_BAD_CERTIFICATE=true
```

这个开关只建议本地临时使用，发布包不要开启。

##### 6. 关闭 Charles 代理

不传 `ENV_ENABLE_CHARLES_PROXY`，或者显式传 `false` 即可关闭：

```bash
flutter run --dart-define=ENV_ENABLE_CHARLES_PROXY=false
```

关闭后 Dio 会恢复正常直连，不再经过 Charles。

### 3.3 core/database

路径：[lib/core/database](lib/core/database)

数据库层使用 `sqflite`，主要负责 App 本地 SQLite 数据库能力。

这里要先分清三种本地存储：

- `SharedPreferences`：适合保存主题、简单开关、小字符串。
- `flutter_secure_storage`：适合保存 token 这类敏感信息。
- `sqflite`：适合保存列表缓存、离线数据、结构化数据。

不要把所有本地数据都塞进 `SharedPreferences`。一旦数据有表结构、查询条件、分页缓存、离线读取需求，就应该放到数据库层。

#### 为什么选择 sqflite

这个项目选择 `sqflite` 作为默认数据库方案。

原因是：

- 使用人数多，Android/iOS 适配成熟。
- 接入成本低，新人容易理解。
- 和当前 `Repository + Riverpod Provider` 架构很容易组合。
- 不需要代码生成，适合作为通用项目骨架。

如果以后项目出现非常复杂的关联查询、强类型 SQL、响应式数据库监听，可以再评估 `drift`。当前骨架优先保持简单、稳定、容易上手。

#### 数据库目录说明

核心文件：

- `app_database.dart`：数据库初始化入口，负责打开数据库文件。
- `database_service.dart`：数据库能力抽象接口，Repository 只依赖它。
- `sqlite_database_service.dart`：`DatabaseService` 的 sqflite 实现。
- `database_tables.dart`：表名、字段名集中管理。
- `database_migrations.dart`：建表和版本升级脚本。
- `database_exception.dart`：数据库异常封装。

这几个文件的关系是：

```text
main.dart
  -> AppDatabase.init()
  -> 打开 SQLite 数据库
  -> 执行 DatabaseMigrations

service_providers.dart
  -> databaseServiceProvider 暴露 DatabaseService
  -> 默认实现 SqliteDatabaseService

Repository
  -> 依赖 DatabaseService
  -> 不直接 import sqflite
```

#### 数据流应该怎么走

数据库不要直接给页面用。

正确的数据流：

```text
View
  -> ViewModel
  -> Repository
  -> DatabaseService
  -> SQLite
```

也就是说：

- `View` 只负责展示和用户操作。
- `ViewModel` 只负责页面状态和业务流程。
- `Repository` 决定数据来自网络、数据库，还是两者结合。
- `DatabaseService` 只负责本地数据库读写。

不要这样做：

```text
View 直接查数据库
ViewModel 直接写 SQL
Repository 直接 import sqflite
```

这样会让页面、状态、存储混在一起，后面测试和维护都会变麻烦。

#### Repository 如何同时使用网络和数据库

以订单模块为例，Repository 可以同时依赖 `ApiService` 和 `DatabaseService`：

```dart
class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl({
    required ApiService apiService,
    required DatabaseService databaseService,
  })  : _apiService = apiService,
        _databaseService = databaseService;

  final ApiService _apiService;
  final DatabaseService _databaseService;
}
```

常见策略是：

```text
先读数据库缓存
  -> 页面尽快展示旧数据

再请求网络
  -> 请求成功后写入数据库
  -> 页面展示最新数据
```

这种写法能兼顾打开速度和数据新鲜度。

#### 通用缓存表示例

项目默认创建了一张通用缓存表：

```text
app_cache
  cache_key     TEXT PRIMARY KEY
  cache_value   TEXT NOT NULL
  updated_at    INTEGER NOT NULL
```

它适合保存简单 JSON 缓存，比如：

- 首页 banner 快照
- 字典配置
- 筛选条件配置
- 一些不复杂的接口响应

如果数据结构复杂，比如订单、商品、消息列表，建议单独建表，不要全部塞进 `app_cache`。

#### 新增一张表怎么做

比如你要新增订单表 `orders`。

第一步：在 [lib/core/database/database_tables.dart](lib/core/database/database_tables.dart) 中增加表名和字段名：

```dart
static const String orders = 'orders';
static const String orderId = 'order_id';
static const String orderTitle = 'title';
static const String orderUpdatedAt = 'updated_at';
```

第二步：在 [lib/core/database/database_migrations.dart](lib/core/database/database_migrations.dart) 中把版本号加 1：

```dart
static const int currentVersion = 2;
```

第三步：给新版本增加 migration：

```dart
case 2:
  await _createVersion2(db);
  break;
```

然后写建表 SQL：

```dart
static Future<void> _createVersion2(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${DatabaseTables.orders} (
      ${DatabaseTables.orderId} TEXT PRIMARY KEY,
      ${DatabaseTables.orderTitle} TEXT NOT NULL,
      ${DatabaseTables.orderUpdatedAt} INTEGER NOT NULL
    )
  ''');
}
```

注意：已经上线的 App 不要随便删表重建。新增字段、新增表、创建索引都应该通过 migration 完成。

#### 新模块怎么接入数据库

比如 `order` 模块需要本地缓存。

推荐顺序：

```text
1. 在 database_tables.dart 中定义 orders 表和字段
2. 在 database_migrations.dart 中新增 migration
3. 在 OrderRepositoryImpl 中注入 DatabaseService
4. Repository 里把数据库 Map 转成 OrderModel
5. ViewModel 继续只调用 OrderRepository
6. View 继续只调用 OrderViewModel
```

用 Riverpod 组装依赖时：

```dart
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(
    apiService: ref.watch(apiServiceProvider),
    databaseService: ref.watch(databaseServiceProvider),
  );
});
```

这样写之后，`OrderViewModel` 不需要知道订单数据是从网络来的，还是从数据库来的。

#### 数据库层的使用边界

请记住这几条：

- 不要在 `View` 里查数据库。
- 不要在 `ViewModel` 里写 SQL。
- 不要让 `Repository` 直接依赖 `sqflite`。
- 表名和字段名统一放在 `DatabaseTables`。
- 数据库版本升级统一放在 `DatabaseMigrations`。
- Repository 单元测试使用 fake `DatabaseService`，不打开 SQLite。
- 验证 `SqliteDatabaseService` 适配器本身时，可以使用 FFI 内存数据库做集成测试。

### 3.4 core/network

路径：[lib/core/network](lib/core/network)

网络层使用 Dio，但业务模块不直接依赖 Dio。

核心文件：

- `api_service.dart`：网络服务抽象接口
- `api_client.dart`：Dio 实现类
- `api_response.dart`：统一响应模型
- `api_exception.dart`：统一异常模型
- `dio_interceptor.dart`：Dio 拦截器
- `endpoints.dart`：接口地址集中管理

#### ApiService

文件：[lib/core/network/api_service.dart](lib/core/network/api_service.dart)

这是 Repository 依赖的网络接口，定义了：

- `get`
- `post`
- `put`
- `delete`
- `upload`

Repository 依赖 `ApiService`，不直接依赖 `ApiClient` 或 Dio。这样测试时可以传 fake 实现。

#### ApiClient

文件：[lib/core/network/api_client.dart](lib/core/network/api_client.dart)

`ApiClient implements ApiService`，是真正的 Dio 请求实现。

它负责：

- 初始化 Dio
- 使用 `EnvConfig` 设置 `baseUrl` 和超时时间
- 统一解析 `ApiResponse<T>`
- 统一转换 `DioException`
- 抛出 `BusinessException`
- 接入 token 拦截器、日志拦截器、401 拦截器、重试拦截器
- 支持文件上传预留接口

#### ApiResponse

文件：[lib/core/network/api_response.dart](lib/core/network/api_response.dart)

后端统一响应结构：

```dart
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;
}
```

`isSuccess` 支持两种模式：

- `EnvConfig.useHttpStatus == true`：HTTP 状态码 200-299 表示成功
- `EnvConfig.useHttpStatus == false`：业务码模式，默认 `code == 0` 表示成功

国内很多后端会返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {}
}
```

当前默认就是兼容这种业务码模式。

#### ApiException / BusinessException

文件：[lib/core/network/api_exception.dart](lib/core/network/api_exception.dart)

`ApiException` 表示通用网络异常，比如：

- 网络连接异常
- 请求超时
- 请求取消
- 服务器错误
- 未知错误

`BusinessException` 表示业务异常，比如：

- 余额不足
- 账号被冻结
- 用户无权限

`AsyncRequestHandler.execute` 会识别 `BusinessException`，优先展示 `userMessage`。

#### Dio 拦截器

文件：[lib/core/network/dio_interceptor.dart](lib/core/network/dio_interceptor.dart)

当前有 4 类拦截器：

- `TokenInterceptor`：请求前自动添加 `Authorization: Bearer token`
- `AppLogInterceptor`：debug 模式打印请求、响应和错误
- `UnauthorizedInterceptor`：遇到 401 时通知 `AuthProvider.logout`
- `RetryInterceptor`：GET、HEAD 遇到临时连接异常或超时时执行退避重试；非幂等请求默认不重试

401 处理有并发保护：多个接口同时返回 401 时，只会触发一次退出登录，避免重复跳转。

#### NetworkStatusService

文件：[lib/core/network/network_status_service.dart](lib/core/network/network_status_service.dart)

`NetworkStatusService` 统一封装网络连接状态，底层使用 `connectivity_plus`。

业务代码不要直接调用 `Connectivity()`，而是通过 `ref.read(networkStatusServiceProvider)` 获取状态：

```dart
final status = await ref.read(networkStatusServiceProvider).getCurrentStatus();

if (!status.isConnected) {
  // 可以选择读取数据库缓存，或者提示用户当前无网络
}
```

它解决的问题是：

- Repository 可以根据网络状态决定是否优先读本地缓存。
- ViewModel 可以在断网时给出更准确的提示。
- 测试时可以用 fake `NetworkStatusService` 替代真实插件。

注意：`connectivity_plus` 判断的是设备连接状态，不保证接口一定能访问。真实接口是否可用，仍然以 Dio 请求结果为准。

### 3.5 core/permission

路径：[lib/core/permission](lib/core/permission)

权限层使用 `permission_handler`，但业务代码不直接依赖它。

核心文件：

- `permission_service.dart`：权限服务抽象和默认实现

常见使用场景：

- 上传头像前申请相机 / 相册权限
- 发语音前申请麦克风权限
- 地图定位前申请定位权限
- 推送功能申请通知权限

推荐用法：

```dart
final result = await ref.read(permissionServiceProvider).request(AppPermissionType.camera);

if (result.isGranted) {
  // 继续打开相机
}

if (result.shouldOpenSettings) {
  await permissionService.openSettings();
}
```

为什么要封装：

- 页面不用关心 `permission_handler` 的具体 API。
- 权限状态可以在项目内统一命名。
- 以后可以统一弹窗文案、统一埋点、统一测试 fake。

新增权限时，在 `AppPermissionType` 中增加枚举，并在 `PermissionHandlerService.mapPermissionType` 中补映射。

### 3.6 core/app

路径：[lib/core/app](lib/core/app)

这里放 App 级别但不属于 UI、网络、数据库的通用能力。

当前文件：

- `app_info_service.dart`：统一获取 App 名称、包名、版本号、构建号

使用方式：

```dart
final appInfo = await ref.read(appInfoServiceProvider).getAppInfo();

print(appInfo.displayVersion); // 1.0.0+1
```

常见使用场景：

- 关于页面展示版本号。
- 日志里带上当前版本。
- 后续接崩溃上报时附带版本信息。

### 3.7 app/navigation 与 shared/navigation

路径：[lib/app/navigation](lib/app/navigation)、[lib/shared/navigation](lib/shared/navigation)

路由使用 GoRouter。路由实例、守卫和主 Shell 属于 App 组合层；不依赖具体页面的路径常量放在 shared，业务页面可以安全引用。

核心文件：

- `route_paths.dart`：路由路径常量
- `app_router.dart`：GoRouter 配置
- `route_guard.dart`：路由守卫抽象

当前路由（使用 `StatefulShellRoute.indexedStack` 管理 Tab）：

```text
/login                     → LoginPage
/splash                    → LoadingView（恢复登录态时）
/riverpod-learning         → RiverpodLearningPage（独立学习中心）
/main                      → 兼容入口，重定向到 /main/home
  /main/home               → HomePage（商品与购物车）
    /main/home/cart        → CartPage（购物车详情）
  /main/orders             → OrdersPage（订单中心）
  /main/mine               → MinePage（我的与设置）
```

`StatefulShellRoute` 保证三个 Tab 共享同一个 `MainShell` 实例，切换 Tab 不销毁子页面并保留滚动位置。Provider 数据是否保留仍由自身生命周期决定，不能把 indexed stack 当成 Provider 缓存策略。

登录拦截规则：

- 未登录访问受保护页面，跳转 `/login`
- 已登录访问 `/login`，跳转 `/main/home`
- 恢复登录态期间停留在 `/splash`
- 未匹配路由展示 `NotFoundPage`

路由守卫被抽成 `RouteGuard`。App 层向 `AuthRouteGuard` 注入 `() => ref.read(authProvider)`，守卫本身不查找 `ProviderScope`；路径判断进一步收敛为纯函数，因此可以脱离 Widget 和 GoRouter 单元测试。守卫统一匹配 `/main` 和 `/main/` 前缀，同时保护独立的 `/riverpod-learning`；未来新增 `/main/*` 深层业务页时不需要维护容易漏项的精确白名单。

首页使用 `context.push(RoutePaths.mainCart)` 进入同一 StatefulShellBranch 下的购物车详情，因此保留底部导航和首页返回栈；学习中心从“我的”右上角进入，是 Shell 外的独立受保护页面。

### 3.8 core/storage

路径：[lib/core/storage](lib/core/storage)

#### LocalStorage

文件：[lib/core/storage/local_storage.dart](lib/core/storage/local_storage.dart)

对 `SharedPreferences` 做了一层封装。

业务代码不要直接使用 `SharedPreferences`，统一通过 `LocalStorage` 访问。

它支持初始化失败降级：如果 `SharedPreferences` 初始化失败，App 仍然可以启动，读写方法会安全返回默认值或 `false`。

#### TokenStorage

文件：[lib/core/storage/token_storage.dart](lib/core/storage/token_storage.dart)

token 使用 `flutter_secure_storage` 存储，不再明文存入 `SharedPreferences`。

注意：`getToken()` 是异步方法，调用时必须 `await`。

### 3.9 core/providers

路径：[lib/core/providers](lib/core/providers)

依赖注入使用 Riverpod 的 `Provider<T>` 和 `NotifierProvider`，替代旧的 `get_it`。Repository 的依赖必须由 Provider 显式组装，不允许在 Repository 内回退到 `ApiClient.instance` 等全局单例。

core 只注册无业务归属的基础设施 Provider：

- `service_providers.dart`：`apiClientProvider`、`apiServiceProvider`、`databaseServiceProvider`、`networkStatusServiceProvider`、`permissionServiceProvider`、`appInfoServiceProvider`

Repository Provider 由各业务模块拥有：

- `features/home/home_providers.dart`：首页缓存、首页 Repository、商品 Repository
- `features/auth/auth_providers.dart`：登录 Repository
- `features/profile/profile_providers.dart`：资料 Repository

这样依赖始终是 feature 指向 core，不会出现 core 为了注册 Repository 而反向导入业务实现。

各 ViewModel 通过独立 Provider 提供（定义在各自的 `view_model.dart` 文件中）。生命周期按业务选择：App 状态和需要跨 Tab 保留的根页面状态使用普通 Provider；跟随详情页、弹窗或一次请求释放的状态使用 `autoDispose`，必要时再通过 `keepAlive` 设置明确 TTL。

App 级 Provider 仍按领域放置，而不是集中到一个 `global/` 目录：

- `authProvider`（`NotifierProvider<AuthNotifier, AuthState>`）—— [lib/features/auth/view_model/auth_view_model.dart](lib/features/auth/view_model/auth_view_model.dart)
- `currentUserIdProvider`（派生 `Provider<String?>`）—— 用户级业务缓存的会话边界
- `themeProvider`（`NotifierProvider<ThemeNotifier, ThemeState>`）—— [lib/shared/theme/theme_provider.dart](lib/shared/theme/theme_provider.dart)

使用方式：

```dart
// 获取服务/仓库
final apiService = ref.read(apiServiceProvider);

// 监听 ViewModel 状态
final state = ref.watch(homeProvider);

// 调用 ViewModel 方法
ref.read(homeProvider.notifier).loadHome();
```

### 3.10 shared/localization

路径：[lib/shared/localization/app_strings.dart](lib/shared/localization/app_strings.dart)

当前没有引入 arb 文件，而是先用 `AppStrings` 集中管理文案。

这样做的好处是：

- 页面里不再散落中文字符串
- 后续接正式多语言时更容易迁移
- 统一修改文案更方便

### 3.11 shared/theme

路径：[lib/shared/theme](lib/shared/theme)

包含：

- `app_theme.dart`：light / dark 主题
- `app_spacing.dart`：统一间距常量
- `app_radius.dart`：统一圆角常量

后续新增页面时，不建议直接写大量魔法数字，比如 `16`、`24`，优先使用：

```dart
AppSpacing.lg
AppSpacing.xl
AppRadius.card
```

### 3.12 core/utils

路径：[lib/core/utils](lib/core/utils)

包含：

- `logger.dart`：debug 日志
- `crash_reporter.dart`：全局异常上报入口
- `json_helper.dart`：JSON 类型转换工具

`CrashReporter` 当前只打印日志，后续接入 Sentry、Bugly 等平台时，可以直接在这里扩展。

## 4. App 级状态的归属

“全局生命周期”不等于“放进 global 目录”。状态仍由所属领域维护：登录会话属于 Auth feature，主题属于 shared/theme；App 组合层只消费它们。

### AuthNotifier（features/auth）

文件：[lib/features/auth/view_model/auth_view_model.dart](lib/features/auth/view_model/auth_view_model.dart)

Riverpod 版本的全局登录态管理器（`Notifier<AuthState>`）。

负责：

- 保存 token 和当前用户（`AuthState` 不可变对象）
- App 启动时从 `TokenStorage` + `LocalStorage` 恢复登录状态
- `loginSuccess(token, user)` 保存登录态并持久化
- `logout()` 清空状态并清除本地存储
- 给 ApiClient 注入 `tokenProvider` 和 `onUnauthorized` 回调

使用方式：

```dart
// 监听登录状态
final authState = ref.watch(authProvider);
authState.isLoggedIn

// 执行登录/退出
ref.read(authProvider.notifier).loginSuccess(token, user);
ref.read(authProvider.notifier).logout();
```

### ThemeNotifier（shared/theme）

文件：[lib/shared/theme/theme_provider.dart](lib/shared/theme/theme_provider.dart)

Riverpod 版本的全局主题管理器（`Notifier<ThemeState>`）。

负责：

- light / dark 切换（`toggleTheme()`）
- 保存用户主题选择到 `LocalStorage`
- 缓存 `ThemeData`（Material 3，`ColorScheme.fromSeed`）

## 5. shared 层

路径：[lib/shared](lib/shared)

### 领域 Model 与公共入口

Model 优先放在拥有它的 feature 中。`UserModel` 属于登录会话领域，因此位于 `features/auth/model`，并由 `features/auth/auth.dart` 对外导出；Mine、Orders、Profile 等模块只依赖该公共入口。

`UserModel` 支持：

- `fromJson`
- `toJson`
- `copyWith`
- `==`
- `hashCode`

Model 推荐使用 `json_serializable` 生成 `fromJson / toJson`。

标准写法：

```dart
import 'package:json_annotation/json_annotation.dart';

part 'order_model.g.dart';

@JsonSerializable()
class OrderModel {
  const OrderModel({
    required this.id,
    required this.title,
  });

  @JsonKey(defaultValue: '')
  final String id;

  @JsonKey(defaultValue: '')
  final String title;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return _$OrderModelFromJson(json);
  }

  Map<String, dynamic> toJson() => _$OrderModelToJson(this);
}
```

新增或修改带 `@JsonSerializable()` 的 Model 后，需要运行：

```bash
dart run build_runner build
```

### shared/ui

通用状态组件：

- `AppNetworkImage`
- `LoadingView`
- `ErrorView`
- `EmptyView`
- `StateView`
- `UserInfoCard`：用户信息卡片（头像占位 + 昵称 + 邮箱），MinePage 和 ProfilePage 共用

`NotFoundPage` 属于 App 导航兜底，放在 `app/navigation`；`RiverpodLearningPanel` 只服务学习业务，放在 `features/learning/view/widgets`。这两个组件都不因“可能复用”而提前进入 shared。

页面状态按数据来源选择表达方式，不强行转换成同一种状态：

- 使用 `ViewState` 的命令式请求页，优先用 `PageShell + StateView` 统一 loading / error / empty。
- 直接消费 `FutureProvider`、`StreamProvider`、`AsyncNotifierProvider` 的页面，优先使用 `AsyncValue.when`。
- 商品、购物车等同步派生列表可以直接判断集合是否为空。

网络图片展示统一使用 `AppNetworkImage`，不要在页面里直接使用 `Image.network` 或 `CachedNetworkImage`。

示例：

```dart
AppNetworkImage(
  imageUrl: banner.imageUrl,
  width: double.infinity,
  height: 160,
  borderRadius: BorderRadius.circular(8),
)
```

这样可以统一处理图片缓存、加载中占位、加载失败占位和圆角。

## 6. features 业务模块

路径：[lib/features](lib/features)

当前已有模块：

```text
features/
  auth/
  home/
  orders/
  mine/
  learning/
  profile/
```

| 模块 | 当前用途 | App 组合层入口 |
| --- | --- | --- |
| `auth` | 登录、会话恢复、退出、用户模型 | `auth.dart` |
| `home` | 商品、收藏、购物车、Banner 请求示例 | `home.dart` |
| `orders` | AsyncNotifier、分页、详情、实时状态 | `orders.dart` |
| `mine` | 登录摘要、主题、App 信息、网络状态 | `mine.dart` |
| `learning` | Riverpod 循序渐进学习中心 | `learning.dart` |
| `profile` | 未来独立资料页，当前保留并有测试 | `profile.dart` |

公共入口只导出 App 或其他模块真正需要的类型；模块内部测试可以直接导入内部文件。新增页面接入 `AppRouter` 时，先把页面加入对应公共入口，再由 App 导入入口文件。

### 6.1 auth 模块

路径：[lib/features/auth](lib/features/auth)

职责：登录、会话恢复、退出以及用户身份模型。它是其他业务唯一允许跨 feature 依赖的领域入口。

结构：

```text
auth/
  auth.dart              # 对外公共入口
  auth_providers.dart    # Repository 依赖组装
  model/
    login_request.dart
    login_response.dart
    user_model.dart
  repository/
    login_repository.dart
  view_model/
    auth_view_model.dart
    login_view_model.dart
  view/
    login_page.dart
```

数据流：

```text
LoginPage
  -> LoginViewModel.login()
  -> LoginRepository.login()
  -> 登录成功后 AuthProvider.loginSuccess()
  -> GoRouter 跳转 /main
```

`LoginPage` 使用 `ConsumerStatefulWidget` + `StateView`（`LoadingStyle.overlay`），登录成功后调用 `authProvider.notifier.loginSuccess()` 并跳转 `/main/home`。

### 6.2 App navigation shell

路径：[lib/app/navigation](lib/app/navigation)

它不再是业务 feature，而是 App 组合层的一部分，负责登录后的主框架页面（使用 GoRouter 的 `StatefulNavigationShell`）。

`MainShell` 接收 `navigationShell` 参数，通过 `BottomNavigationBar` + `navigationShell.goBranch(index)` 切换 Tab。GoRouter 的 `StatefulShellRoute.indexedStack` 管理子页面生命周期，保证切换时状态保留。

三个 Tab 按业务复杂度和学习难度排列：

- 商品：`HomePage`——同步交互、局部订阅和派生状态
- 订单：`OrdersPage`——异步状态机、参数化缓存和实时流
- 我的：`MinePage`——跨路由状态、服务注入和插件隔离

不再需要 `MainViewModel`——Tab 选择和子路由栈由 GoRouter 的 `StatefulNavigationShell` 管理。需要注意：Widget 树被 indexed stack 保留，不等于 auto-dispose Provider 一定保留。Riverpod 3 会暂停非当前 Tab 的订阅，因此根 Tab 要长期保留的业务状态使用非 auto-dispose Provider。

### 6.3 home 模块

路径：[lib/features/home](lib/features/home)

职责：以商品目录、收藏和购物车为业务背景，展示同步状态和最常用的 WidgetRef API。

结构：

```text
home/
  home.dart
  home_providers.dart
  model/
    product.dart
    home_banner.dart
  repository/
    product_repository.dart
    home_repository.dart
  view_model/
    catalog_view_model.dart
    home_view_model.dart
  view/
    home_page.dart
    cart_page.dart
```

`HomeRepositoryImpl` 已示范 Repository 内存缓存：

```text
fetchBanners()
  -> 先 readCache()
  -> 有缓存：立即返回缓存，并后台拉新数据
  -> 无缓存：请求远端数据，再 writeCache()
```

当前没有真实后端，通过 `EnvConfig.enableMock` 使用模拟数据；需要真实接口时通过 `--dart-define=ENV_ENABLE_MOCK=false` 切换。

当前 `HomePage` 和 `CartPage` 按一个完整的商品浏览流程组织：

1. `productRepositoryProvider` 用 `Provider` 注入只读 Repository，测试可 override。
2. `catalogFilterProvider` 用 `NotifierProvider` 保存搜索、分类和“只看收藏”。
3. `favoriteProductIdsProvider` 与 `cartProvider` 分开维护收藏和购物车，避免一个巨大 State 让所有卡片重建。
4. 三个业务 Notifier 都依赖 `currentUserIdProvider`，切换账号会自动清空搜索、收藏和购物车。
5. `visibleProductsProvider` 只在“只看收藏”开启时依赖收藏 Set；普通收藏动作只重建目标卡片。
6. `cartQuantityProvider(productId)` 用 `autoDispose.family + select` 让商品卡片只监听自己的数量，并在卡片离开后释放 family 实例。
7. 首页右上角购物车使用 `context.push(RoutePaths.mainCart)` 进入详情，不再把图标绑定为清空命令。
8. `cartLineItemsProvider` 从商品目录和 `cartProvider` 派生 `CartLineItem`，购物车页面不保存第二份可变明细。
9. `cartSummaryProvider` 从商品与购物车派生总件数、总价，避免手工同步多个字段。
10. `CartPage` 支持单项增减、整项移除、总价展示和带二次确认的清空操作；空购物车可以返回继续购物。
11. View 用 `ref.watch` 渲染、`ref.read` 发送命令、`ref.listen` 展示加购 SnackBar。

购物车数据流：

```text
ProductRepository -> productsProvider
                            +
                     cartProvider
                       |    |    |
                       |    |    +-> cartSummaryProvider
                       |    +------> cartLineItemsProvider -> CartPage
                       +-----------> cartQuantityProvider(id) -> ProductCard
```

`cartProvider` 是当前用户会话中的唯一可变购物车状态。进入详情、返回商品页或切换 Tab 都会保留；退出登录、切换账号或 App 进程重启会重建。当前示例没有把购物车写入数据库，避免把演示中的内存状态误认为持久化购物车。

这组代码适合先阅读 [catalog_view_model.dart](lib/features/home/view_model/catalog_view_model.dart)，再依次对照 [home_page.dart](lib/features/home/view/home_page.dart) 和 [cart_page.dart](lib/features/home/view/cart_page.dart)，理解“状态归谁所有”“派生状态为什么不重复保存”和“Widget 应监听多小的切片”。

Banner Repository、CancelToken 和 HomeNotifier 仍作为网络请求与生命周期示例保留，并由独立测试覆盖。

### 6.4 orders 模块

路径：[lib/features/orders](lib/features/orders)

职责：模拟订单从列表到详情的完整异步生命周期，重点展示真实项目中“首屏状态”和“局部命令状态”如何分开。

当前包含：

- `model/order.dart`：订单、订单状态和分页结果，保持纯 Dart、不可变
- `repository/order_repository.dart`：Repository 接口及分页、详情、创建、取消、实时状态的 Mock 实现
- `view_model/order_view_model.dart`：订单状态机、派生 Provider 和详情/实时状态 Provider
- `view/orders_page.dart`：渲染 `AsyncValue`、发送用户命令、处理 SnackBar 副作用

主要业务处理：

- 首次加载用 `AsyncNotifier.build()`；Provider 的 `retry` 只对连接、超时和 5xx 等瞬时错误最多重试两次，不重试取消、权限和业务错误。
- 下拉刷新使用 `ref.refresh(orderFeedProvider.future)`；彻底清空并重建使用 `ref.invalidate`。
- Repository 所有 Future 接口都透传 `CancelToken`；初载和命令请求会在 Provider 销毁或登录用户变化时取消。
- 分页和创建只切换局部 loading，不清空已有列表，也不把整个页面变成 `AsyncLoading`。
- 每次 `await` 后基于最新 `state.value` 合并结果，避免并发命令用旧快照覆盖新状态。
- Mock 的 offset 分页按订单 id 去重；真实接口优先使用 cursor 分页。
- 取消订单先乐观更新，Repository 失败时恢复旧订单；取消期间到达的实时状态会按 id 暂存，回滚时合并最新远端状态，不会用旧快照覆盖物流推进。
- 初载错误用 `AsyncError` 展示错误页；分页/创建/取消错误保留列表，并通过一次性 `OrderOperationResult` + `ref.listen` 展示。
- `FutureProvider.autoDispose.family` 为每个订单 id 创建独立详情；未完成时关闭弹窗立即取消 `CancelToken`，成功后才用 `keepAlive + onCancel/onResume` 保留 30 秒。
- `StreamProvider.autoDispose.family` 模拟 WebSocket/SSE；详情关闭后自动取消订阅，并把远端状态同步回订单列表。Mock 为了确定性只在订阅后模拟推进，真实服务端状态应独立运行。
- 异步间隙后用 `ref.mounted` 阻止已销毁 Notifier 回写。

对应测试 [order_providers_test.dart](test/features/orders/order_providers_test.dart) 演示 `ProviderContainer`、Repository override、分页/创建并发、实时事件与回滚竞态、family 参数隔离、TTL 到期、详情请求取消，以及 Stream 订阅自动释放。

### 6.5 mine 模块

路径：[lib/features/mine](lib/features/mine)

职责：以个人中心与设置为背景，展示 App 级状态、页面级异步状态与底层服务注入。

当前场景：

- `authProvider`：跨路由共享登录态，并驱动 GoRouter redirect
- `themeProvider`：全局主题切换与本地持久化
- `select`：页面只监听 `themeMode`、当前用户等必要字段
- `FutureProvider.autoDispose<AppInfo>`：把 AppInfoService 转换成 AsyncValue
- `StreamProvider.autoDispose<NetworkStatus>`：隔离 connectivity_plus 并监听连接变化
- Service Provider override：测试时用 FakeAppInfoService/FakeNetworkStatusService 替换插件
- `ref.invalidate(appInfoProvider)`：主动销毁并重新读取 App 信息
- AppBar 右上角学士帽使用 `context.push(RoutePaths.riverpodLearning)` 打开独立学习中心，业务 Tab 正文不混入教学导航

退出登录流程：

```text
MinePage
  -> AuthProvider.logout()
  -> 清空 token 和用户信息
  -> GoRouter 跳转 /login
```

### 6.6 learning 模块

路径：[lib/features/learning](lib/features/learning)

职责：提供独立的 Riverpod 学习中心。用户从“我的”页面右上角进入，按“基础 → 异步 → 全局”阅读；商品、订单、我的三个业务 Tab 只保留业务 UI。

结构：

```text
learning/
  learning.dart
  model/
    riverpod_lesson.dart
  repository/
    riverpod_learning_repository.dart
  view_model/
    riverpod_learning_view_model.dart
  view/
    riverpod_learning_page.dart
    widgets/
      riverpod_learning_panel.dart
```

自身也遵循 MVVM + Riverpod：

- `RiverpodLesson` 和 `RiverpodCodeExample` 是纯 Dart、不可变 Model。
- `RiverpodLearningRepository` 隔离课程来源；当前 `LocalRiverpodLearningRepository` 返回本地课程，未来可替换为 JSON、Markdown 或远端配置。
- `riverpodLearningRepositoryProvider` 注入 Repository，测试可以 override。
- `riverpodLessonsProvider` 暴露只读课程集合。
- `riverpodLessonStageProvider` 使用 `NotifierProvider.autoDispose` 管理当前阅读阶段，离开学习页后释放。
- `currentRiverpodLessonProvider` 根据课程集合和当前阶段派生当前课程，不重复保存课程对象。
- `RiverpodLearningPage` 只负责 `watch`、渲染、阶段切换和进入对应业务实战。

学习中心数据流：

```text
LocalRiverpodLearningRepository
  -> riverpodLessonsProvider
  +  riverpodLessonStageProvider
  -> currentRiverpodLessonProvider
  -> RiverpodLearningPage
```

每一站统一展示业务场景、Riverpod API、数据流、可操作 UI、真实代码入口和可展开代码片段。代码片段用于快速理解 API，项目中的 `features/home`、`features/orders`、`features/mine` 与测试文件才是完整实战实现。

更完整的阅读顺序见 [docs/riverpod_learning_path.md](docs/riverpod_learning_path.md)。

### 6.7 profile 模块

路径：[lib/features/profile](lib/features/profile)

这是早期个人中心模块，目前主 Tab 已使用 `MinePage`。它不是冗余删除候选，而是保留给未来独立资料页的完整能力：`profile_providers.dart` 负责 Repository 注入，Repository/ViewModel 继续透传 `CancelToken`，`profile.dart` 提供公共入口，并有 ViewModel 测试保护。当前尚未在 `AppRouter` 注册入口，需要启用时只需增加路径和路由。

## 7. MVVM + Repository 数据流

项目推荐的数据流：

```text
View
  -> ViewModel
  -> Repository
  -> ApiService
  -> ApiClient(Dio)
```

反向更新：

```text
ApiClient 返回数据
  -> Repository 转换成 Model
  -> Notifier 更新 state（不可变对象）并切换 ViewState
  -> Riverpod 通知监听者
  -> ConsumerWidget / ConsumerStatefulWidget 通过 ref.watch 刷新 UI
```

各层职责：

### View

只负责：

- 画 UI
- 收集用户输入
- 响应点击事件
- 调用 Notifier 方法（`ref.read(provider.notifier).xxx()`）
- 做页面跳转

不要在 View 中直接调用 Dio 或 Repository。使用 `ConsumerWidget` / `ConsumerStatefulWidget`。

### ViewModel（Notifier）

负责：

- 页面状态（不可变 state 对象）
- 页面业务逻辑
- 调用 Repository（通过 `ref.read` 获取）
- 暴露页面需要的数据字段
- 通过 `state = state.copyWith(viewState: ...)` 切换状态

不要在 Notifier 中直接创建 Dio。使用 `AsyncRequestHandler` 管理异步请求。

### Repository

负责：

- 请求数据
- 转换数据
- 管理数据来源（Mock / 真实 API，通过 `EnvConfig.enableMock` 切换）
- 可选缓存策略

不要在 Repository 中依赖 `BuildContext`，也不要处理 UI 状态。

### ApiClient

负责：

- 真实网络请求
- 拦截器
- token
- 统一响应解析
- 统一异常转换

## 8. 新增业务模块应该怎么做

项目中的 `orders` 已用于演示 `AsyncNotifier` 状态机。下面再假设新增一个更简单、进入页面后显式加载的 `coupon` 模块，用来说明带 `CancelToken` 的通用请求型页面：

### 1. 创建目录

```text
lib/features/coupon/
  coupon.dart
  coupon_providers.dart
  model/
    coupon_model.dart
  repository/
    coupon_repository.dart
  view_model/
    coupon_view_model.dart
  view/
    coupon_page.dart
```

### 2. 定义 Model

```dart
class CouponModel {
  const CouponModel({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: asOr(json['id'], ''),
      title: asOr(json['title'], ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
    };
  }
}
```

### 3. 定义 Repository 接口和实现

如果 Repository 里需要把列表缓存成 JSON 字符串，记得导入：

```dart
import 'dart:convert';
```

```dart
abstract class CouponRepository {
  Future<List<CouponModel>> fetchCoupons({CancelToken? cancelToken});
}

class CouponRepositoryImpl implements CouponRepository {
  CouponRepositoryImpl({
    required ApiService apiService,
    required DatabaseService databaseService,
  })  : _apiService = apiService,
        _databaseService = databaseService;

  final ApiService _apiService;
  final DatabaseService _databaseService;

  @override
  Future<List<CouponModel>> fetchCoupons({CancelToken? cancelToken}) async {
    // 示例：先查询数据库缓存，让页面在弱网时也有数据可展示。
    final cachedRows = await _databaseService.query(
      DatabaseTables.appCache,
      where: '${DatabaseTables.cacheKey} = ?',
      whereArgs: ['coupons'],
      limit: 1,
    );

    if (cachedRows.isNotEmpty) {
      final cacheValue = cachedRows.first[DatabaseTables.cacheValue] as String;
      final cachedJson = jsonDecode(cacheValue) as List<dynamic>;
      final cachedCoupons = asList(cachedJson, CouponModel.fromJson);

      if (cachedCoupons.isNotEmpty) {
        return cachedCoupons;
      }
    }

    final response = await _apiService.get<List<CouponModel>>(
      '/coupons',
      cancelToken: cancelToken,
      fromJson: (json) => asList(
        json,
        CouponModel.fromJson,
      ),
    );
    final couponList = response.data ?? [];

    // 示例：网络成功后，把接口结果写入数据库。
    // 这里为了演示使用通用缓存表；复杂、可查询的业务数据应建立独立表。
    await _databaseService.insert(
      DatabaseTables.appCache,
      {
        DatabaseTables.cacheKey: 'coupons',
        DatabaseTables.cacheValue: jsonEncode(
          couponList.map((coupon) => coupon.toJson()).toList(),
        ),
        DatabaseTables.cacheUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      replaceOnConflict: true,
    );

    return couponList;
  }
}
```

### 4. 注册 Repository Provider

在 feature 自己的 `coupon_providers.dart` 中组装 Repository：

```dart
final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return CouponRepositoryImpl(
    apiService: ref.watch(apiServiceProvider),
    databaseService: ref.watch(databaseServiceProvider),
  );
});
```

core 只提供 `apiServiceProvider` 等基础设施依赖，不导入 `CouponRepository`。测试通过 override 此 Provider 替换 Repository。

### 5. 定义 Notifier + State

```dart
// coupon_state.dart
class CouponState {
  const CouponState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    this.coupons = const [],
  });
  final ViewState viewState;
  final String errorMessage;
  final List<CouponModel> coupons;
  CouponState copyWith({...}) => ...;
}

// coupon_notifier.dart
class CouponNotifier extends Notifier<CouponState> {
  late final _handler = AsyncRequestHandler();

  @override
  CouponState build() {
    ref.onDispose(() => _handler.dispose());
    return const CouponState();
  }

  Future<void> loadCoupons() async {
    final data = await _handler.execute<List<CouponModel>>(
      request: () => ref.read(couponRepositoryProvider).fetchCoupons(
            cancelToken: _handler.cancelToken,
          ),
      onLoading: () => state = state.copyWith(viewState: ViewState.loading),
      onSuccess: () => state = state.copyWith(viewState: ViewState.success),
      onEmpty: () => state = state.copyWith(viewState: ViewState.empty),
      onError: (msg) => state = state.copyWith(viewState: ViewState.error, errorMessage: msg),
      isEmpty: (data) => data.isEmpty,
    );
    if (ref.mounted && data != null) {
      state = state.copyWith(coupons: data);
    }
  }
}

final couponProvider =
    NotifierProvider.autoDispose<CouponNotifier, CouponState>(
      CouponNotifier.new,
    );
```

Riverpod 3 已统一 Notifier 接口：即使 Provider 使用 auto-dispose，类仍然继承 `Notifier<State>`，不再继承旧的 `AutoDisposeNotifier<State>`。

### 6. 定义 Page

```dart
class CouponPage extends ConsumerStatefulWidget {
  const CouponPage({super.key});
  @override
  ConsumerState<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends ConsumerState<CouponPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(couponProvider.notifier).loadCoupons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(couponProvider);
    return PageShell(
      viewState: state.viewState,
      errorMessage: state.errorMessage,
      onRetry: () => ref.read(couponProvider.notifier).loadCoupons(),
      builder: (context) => ListView.builder(
        itemCount: state.coupons.length,
        itemBuilder: (_, i) => Text(state.coupons[i].title),
      ),
    );
  }
}
```

### 7. 公开页面并增加路由

先在 `coupon.dart` 公开 App 组合层需要的页面：

```dart
export 'view/coupon_page.dart';
```

然后在 `RoutePaths` 增加路径，在 `AppRouter` 增加 `GoRoute`。App 只导入 `features/coupon/coupon.dart`，不直接导入 `view/coupon_page.dart`。完成后运行架构测试确认依赖没有越界。

## 9. 接入真实后端需要改哪里

### 1. 修改 baseUrl

推荐通过 `--dart-define`：

```bash
flutter run --dart-define=ENV_API_BASE_URL=https://api.your-domain.com
```

也可以修改 [lib/core/config/env_config.dart](lib/core/config/env_config.dart) 的默认值。

### 2. 修改接口路径

在 [lib/core/network/endpoints.dart](lib/core/network/endpoints.dart) 中集中维护接口路径。

### 3. 关闭 Mock 模式

项目默认使用 Mock 数据（`EnvConfig.enableMock` 默认 `true`）。接真实后端时：

```bash
flutter run --dart-define=ENV_ENABLE_MOCK=false
```

每个 Repository 都内置了 Mock / 真实 API 两条路径，通过 `envConfig.enableMock` 自动切换，不需要手动注释或取消注释代码。

### 4. 按需接入本地数据库缓存

如果某个接口需要离线展示、减少重复请求、提升打开速度，可以在对应 Repository 中同时注入 `DatabaseService`。

推荐做法：

```text
Repository 先读数据库缓存
  -> 有缓存时先返回缓存
  -> 没缓存或需要刷新时请求网络
  -> 网络成功后写入数据库
```

注意：不要在 ViewModel 里直接操作数据库。ViewModel 仍然只调用 Repository。

### 5. 确认响应结构

如果后端响应不是：

```json
{
  "code": 0,
  "message": "success",
  "data": {}
}
```

需要修改 [lib/core/network/api_response.dart](lib/core/network/api_response.dart)。

### 6. 确认成功码

默认业务成功码是 `0`。

如果后端是 HTTP 状态码模式，可以启动时传：

```bash
flutter run --dart-define=ENV_USE_HTTP_STATUS=true
```

如果后端业务成功码不是 0，可以传：

```bash
flutter run --dart-define=ENV_API_SUCCESS_CODE=200
```

## 10. 如何编写单元测试

这个项目的测试重点是：**业务单元测试不访问真实网络或设备数据库**。Repository 使用 Fake Service；SQLite 适配器使用独立的 FFI 内存数据库测试 CRUD、事务和异常转换，不接触 App 的真实数据库文件。

测试使用 Riverpod 的 `ProviderContainer` + `overrides` 来替换依赖，替代旧的 get_it `register`/`reset` 模式。

```text
测试中通过 ProviderContainer.overrides 替换 Repository
  -> 从 container.read(provider.notifier) 获取 Notifier
  -> 调用 Notifier 方法
  -> 断言 Notifier.state 暴露给 View 的字段
```

### 10.1 测试目录建议

```text
test/
  app/navigation/             # Router、Guard、RoutePaths
  architecture/               # 模块依赖规则
  codegen/                    # JSON 生成代码契约
  core/                       # 数据库、网络、权限等基础设施
  features/
    auth/
      login_view_model_test.dart
    home/
      home_view_model_test.dart
      home_provider_lifecycle_test.dart
    orders/
      order_providers_test.dart
  shared/                     # 状态处理器、主题和通用 UI
```

测试目录尽量镜像生产代码；架构测试单独放在 `test/architecture`，因为它验证的是整个 `lib` 的依赖方向，而不是某一个业务模块。

### 10.2 ViewModel 单元测试写法

以 `LoginNotifier` 为例。

第一步：写一个 fake Repository。

```dart
class FakeLoginRepository implements LoginRepository {
  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    CancelToken? cancelToken,
  }) async {
    return const LoginResponse(
      token: 'fake_token',
      user: UserModel(id: '1', name: 'Test User', email: 'test@example.com'),
    );
  }
}
```

第二步：用 `ProviderContainer` + `overrides` 创建被测 Notifier。

```dart
test('login notifier uses fake repository', () async {
  final container = ProviderContainer(
    overrides: [
      loginRepositoryProvider.overrideWith((ref) => FakeLoginRepository()),
    ],
  );

  final notifier = container.read(loginProvider.notifier);
  final success = await notifier.login('test@example.com', '123456');

  expect(success, isTrue);
  expect(notifier.state.token, 'fake_token');
  expect(notifier.state.user?.name, 'Test User');
});
```

Riverpod 3 也提供 `ProviderContainer.test()` 自动管理测试容器；当前项目继续使用 `ProviderContainer` 时，应通过 `addTearDown(container.dispose)` 或显式 `dispose()` 释放容器。

### 10.3 列表页 Notifier 测试写法

```dart
class FakeHomeRepository implements HomeRepository {
  @override
  Future<List<HomeBanner>> fetchBanners({CancelToken? cancelToken}) async {
    return const [HomeBanner(id: '1', title: 'Fake Banner', imageUrl: '')];
  }
}

test('home notifier uses fake repository', () async {
  final container = ProviderContainer(
    overrides: [
      homeRepositoryProvider.overrideWith((ref) => FakeHomeRepository()),
    ],
  );

  final notifier = container.read(homeProvider.notifier);
  await notifier.loadHome();

  expect(notifier.state.banners, hasLength(1));
  expect(notifier.state.banners.first.title, 'Fake Banner');
});
```

### 10.4 为什么用 ProviderContainer.overrides

不要这样写：

```dart
final notifier = HomeNotifier(); // 无法注入依赖
```

推荐用 `ProviderContainer` + `overrides`：

- 测试路径和真实 App 的 Provider 创建方式一致。
- 可以精确替换某一层的依赖（如只替换 Repository，保留真实 ApiService）。
- 不需要 `setUp`/`tearDown` 中的 `reset()`——每个测试创建新的 `ProviderContainer` 即可隔离。

### 10.5 Widget 测试注意点

Widget 测试需要包裹 `ProviderScope`：

```dart
SharedPreferences.setMockInitialValues({});
FlutterSecureStorage.setMockInitialValues({});
await LocalStorage.init();

await tester.pumpWidget(const ProviderScope(child: MyApp()));
await tester.pumpAndSettle();
```

### 10.6 Repository 测试如何 fake 数据库

Repository 如果同时依赖网络和数据库，不要在单元测试里真的打开 SQLite。

推荐写一个 fake `DatabaseService`：

```dart
class FakeDatabaseService implements DatabaseService {
  final Map<String, List<Map<String, Object?>>> tables = {};

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceOnConflict = false,
  }) async {
    final rows = tables.putIfAbsent(table, () => []);
    rows.add(values);
    return rows.length;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool distinct = false,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return tables[table] ?? [];
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return 0;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    tables.remove(table);
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, {
    List<Object?>? arguments,
  }) async {
    return [];
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(DatabaseService service) action,
  ) {
    return action(this);
  }

  @override
  Future<void> clearTable(String table) async {
    tables.remove(table);
  }
}
```

测试 Repository 时可以这样组装：

```dart
setUp(() async {
  container = ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWith((ref) => FakeApiService()),
      databaseServiceProvider.overrideWith((ref) => FakeDatabaseService()),
    ],
  );
  addTearDown(container.dispose);

  repository = OrderRepositoryImpl(
    apiService: container.read(apiServiceProvider),
    databaseService: container.read(databaseServiceProvider),
  );
});
```

这样测试的是 Repository 的数据转换和缓存逻辑，不依赖真实网络和真实 SQLite。

### 10.7 应该测什么，不应该测什么

ViewModel 单元测试应该测：

- 调用成功后，ViewModel 暴露给 View 的字段是否正确。
- 空数据时是否进入 empty 状态。
- 业务失败时是否进入 error 状态。
- 表单校验逻辑是否正确。
- 是否调用了 fake Repository 的预期方法。

ViewModel 单元测试不应该测：

- Dio 真实网络请求。
- UI 具体长什么样。
- GoRouter 是否真的跳转。
- SharedPreferences / SecureStorage 的真实读写。
- SQLite 的真实文件读写。

Repository 单元测试可以测：

- JSON 是否能正确转 Model。
- 缓存命中时是否优先返回缓存。
- fake ApiService 返回不同数据时，Repository 是否转换正确。
- fake DatabaseService 有缓存时，Repository 是否按预期读取缓存。

Widget 测试可以测：

- 未登录时是否显示登录页。
- 登录按钮点击后是否进入主页面。
- 页面上关键文案或按钮是否存在。

### 10.8 当前已有测试示例

可以参考：

- [test/features/auth/login_view_model_test.dart](test/features/auth/login_view_model_test.dart)
- [test/features/profile/profile_view_model_test.dart](test/features/profile/profile_view_model_test.dart)
- [test/features/home/home_view_model_test.dart](test/features/home/home_view_model_test.dart)
- [test/features/home/home_provider_lifecycle_test.dart](test/features/home/home_provider_lifecycle_test.dart)
- [test/features/home/catalog_providers_test.dart](test/features/home/catalog_providers_test.dart)
- [test/features/home/cart_page_test.dart](test/features/home/cart_page_test.dart)
- [test/features/orders/order_providers_test.dart](test/features/orders/order_providers_test.dart)
- [test/features/mine/mine_service_providers_test.dart](test/features/mine/mine_service_providers_test.dart)
- [test/features/learning/riverpod_learning_view_model_test.dart](test/features/learning/riverpod_learning_view_model_test.dart)
- [test/features/learning/riverpod_learning_page_test.dart](test/features/learning/riverpod_learning_page_test.dart)
- [test/features/learning/riverpod_learning_panel_test.dart](test/features/learning/riverpod_learning_panel_test.dart)
- [test/features/auth/login_page_navigation_test.dart](test/features/auth/login_page_navigation_test.dart)
- [test/app/navigation/app_router_test.dart](test/app/navigation/app_router_test.dart)
- [test/app/navigation/route_guard_test.dart](test/app/navigation/route_guard_test.dart)
- [test/app/navigation/route_paths_test.dart](test/app/navigation/route_paths_test.dart)
- [test/architecture/dependency_rules_test.dart](test/architecture/dependency_rules_test.dart)
- [test/shared/state/async_request_handler_test.dart](test/shared/state/async_request_handler_test.dart)
- [test/shared/state/paginated_handler_test.dart](test/shared/state/paginated_handler_test.dart)
- [test/core/database/sqlite_database_service_test.dart](test/core/database/sqlite_database_service_test.dart)
- [test/features/auth/auth_provider_test.dart](test/features/auth/auth_provider_test.dart)
- [test/shared/theme/theme_provider_test.dart](test/shared/theme/theme_provider_test.dart)

生命周期测试会验证关闭页面 Provider 的最后一个监听者后，进行中的 Dio 请求收到取消信号；业务测试覆盖同步派生状态、购物车共享与确认清空、异步分页/回滚/family 缓存，以及 Future/Stream 服务替换；基础设施测试覆盖请求处理器、分页、SQLite 事务、路由守卫和全局会话/主题持久化；学习中心测试覆盖阶段状态和窄屏切换。README 不固定记录测试总数，避免新增测试后文档数字失真；以 `flutter test` 实际结果为准。

## 11. 工程工具和常用命令

### 11.1 JSON 代码生成

项目已接入：

- `json_annotation`
- `json_serializable`
- `build_runner`

修改带 `@JsonSerializable()` 的 Model 后，运行：

```bash
dart run build_runner build
```

如果你希望监听文件变化自动生成，可以运行：

```bash
dart run build_runner watch
```

生成文件一般是：

```text
xxx.g.dart
```

这些文件需要提交到仓库。原因是其他开发者拉代码后可以直接运行，不一定每次都先执行生成命令。

### 11.2 启动图和 App 图标

项目已添加开发工具依赖：

- `flutter_native_splash`
- `flutter_launcher_icons`

当前骨架项目没有真实品牌图，所以没有生成默认图标和启动图，避免后续项目还要删除假素材。

等具体项目有品牌图后，可以在 `pubspec.yaml` 中补配置：

```yaml
flutter_native_splash:
  color: "#FFFFFF"
  color_dark: "#121212"
  android: true
  ios: true

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/app/icon.png"
```

然后执行：

```bash
flutter pub run flutter_native_splash:create
flutter pub run flutter_launcher_icons
```

建议图标素材放在：

```text
assets/app/icon.png
```

如果项目暂时没有品牌图，不要随便放一张临时图提交。真实项目早期用系统默认图标，比提交一张以后要清理的假图更稳。

### 11.3 可选：用 Mason 生成业务模块

当项目后续频繁新增 `order`、`product`、`message` 等模块时，可以再引入 Mason。**当前仓库没有提交 `mason.yaml` 或 brick**，下面是扩展建议，不是运行本项目的必需步骤。

每个模块都建议保持同样结构：

```text
features/order/
  order.dart
  order_providers.dart
  model/
    order_model.dart
  repository/
    order_repository.dart
  view_model/
    order_view_model.dart
  view/
    order_page.dart
```

如果每次都手动创建这些文件，很容易出现命名不统一、目录漏建、基础代码风格不一致的问题。

推荐使用 `mason_cli` 做命令行模板生成。

#### 1. 安装 Mason

Mason 是命令行工具，不需要写进项目依赖。

全局安装：

```bash
dart pub global activate mason_cli
```

如果终端提示找不到 `mason` 命令，需要把 pub global bin 加到 PATH。

常见路径：

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

可以写到 `~/.zshrc` 或 `~/.bashrc` 中。

验证安装：

```bash
mason --version
```

#### 2. 初始化 Mason

在项目根目录执行：

```bash
mason init
```

执行后会生成：

```text
mason.yaml
```

后续所有 brick 都会登记在 `mason.yaml` 里。

#### 3. 创建 feature 模块模板

推荐把模板放到：

```text
bricks/feature_module/
```

创建 brick：

```bash
mason new feature_module
```

如果命令在当前目录生成了 `feature_module`，可以按团队习惯移动到 `bricks/feature_module`，然后在 `mason.yaml` 中登记：

```yaml
bricks:
  feature_module:
    path: bricks/feature_module
```

#### 4. 模板建议生成哪些文件

`feature_module` brick 建议生成：

```text
lib/features/{{name.snakeCase()}}/
  {{name.snakeCase()}}.dart
  {{name.snakeCase()}}_providers.dart
  model/
    {{name.snakeCase()}}_model.dart
  repository/
    {{name.snakeCase()}}_repository.dart
  view_model/
    {{name.snakeCase()}}_view_model.dart
  view/
    {{name.snakeCase()}}_page.dart
```

比如生成订单模块：

```bash
mason make feature_module --name order
```

期望生成：

```text
lib/features/order/
  order.dart
  order_providers.dart
  model/
    order_model.dart
  repository/
    order_repository.dart
  view_model/
    order_view_model.dart
  view/
    order_page.dart
```

#### 5. 模板代码应该遵守当前架构

生成出来的代码建议保持这些规则：

- `Page` 有 Controller/一次性初始化时使用 `ConsumerStatefulWidget`，否则优先 `ConsumerWidget`。
- 同步业务状态使用 `Notifier`，异步初始化状态使用 `AsyncNotifier`；只有命令式请求需要时才组合 `AsyncRequestHandler`。
- `ViewModel` 只调用 `Repository`，不直接调用 Dio 或数据库。
- `Repository` 依赖 `ApiService`、`DatabaseService` 等抽象服务。
- `Model` 使用 `json_serializable`。
- 文件顶部保留简短路径注释，方便新人定位。

#### 6. 生成模块后还需要手动做什么

Mason 负责生成模块文件，但下面几步通常需要开发者确认：

1. 确认 `<feature>_providers.dart` 只组装本 feature 的 Repository。
2. 在 `<feature>.dart` 中仅导出 App 或其他模块需要的公开 API。
3. 在 [lib/shared/navigation/route_paths.dart](lib/shared/navigation/route_paths.dart) 增加路由常量。
4. 在 [lib/app/navigation/app_router.dart](lib/app/navigation/app_router.dart) 通过 feature 公共入口增加 `GoRoute`。
5. 如果新增了本地数据库表，在 `DatabaseTables` 和 `DatabaseMigrations` 中补表结构。
6. 如果新增了 `@JsonSerializable()` Model，运行代码生成。

常用命令：

```bash
dart run build_runner build
flutter analyze
flutter test
```

#### 7. 为什么先用 Mason，不急着写 VSCode 插件

Mason 更适合当前阶段：

- 命令行即可使用，团队成员不用安装自研插件。
- 模板文件直接提交到项目，版本跟项目一起走。
- 维护成本低，适合快速迭代模板。
- 后续如果确实需要 VSCode 一键生成，可以让插件内部调用 Mason。

所以推荐路线是：

```text
先维护 Mason brick
  -> 团队稳定使用
  -> 再考虑包一层 VSCode 插件
```

### 11.4 新增通用库的原则

新增三方库时，优先遵循这几条：

- 能封装就封装，业务层不要直接依赖三方库。
- 优先放到 `core/` 或 `shared/`，再通过接口暴露给业务模块。
- Repository 只依赖抽象服务，比如 `ApiService`、`DatabaseService`、`NetworkStatusService`。
- ViewModel 不直接操作 Dio、SQLite、permission_handler、connectivity_plus。
- 新增通用能力时同步补 README 和测试。

当前不接崩溃上报。`CrashReporter` 保留为统一入口，后续确定平台后再接 Firebase Crashlytics、Sentry 或 Bugly。

### 11.5 常用命令

安装依赖：

```bash
flutter pub get
```

静态检查：

```bash
flutter analyze
```

运行测试：

```bash
flutter test
```

运行 App：

```bash
flutter run
```

指定环境运行：

```bash
flutter run \
  --dart-define=ENV_API_BASE_URL=https://dev-api.example.com \
  --dart-define=ENV_RETRY_COUNT=2
```

## 12. 架构设计哲学

这一节解释"为什么这样设计"，而不仅仅是"代码怎么写"。理解这些决策，能帮你在扩展项目时保持架构一致性。

### 12.1 组合优于继承：为什么 AsyncRequestHandler 是工具类而不是基类

旧的 `BaseViewModel extends ChangeNotifier` 被替换为独立的 `AsyncRequestHandler` 工具类。这不是为了省代码，而是一个刻意的架构选择：

**如果做成基类**，所有 ViewModel 都必须继承它，这导致：
- 无法从 Riverpod 的 `Notifier<State>` 自由继承（泛型参数被基类锁死）
- 不需要请求管理的 ViewModel（如表单绑定、纯本地状态）被迫携带 `asyncRequest` 的包袱
- 需要多个处理器（如一个普通请求 + 一个上传进度）时无法组合

**做成工具类**后：
- 每个 Notifier 按需创建 `AsyncRequestHandler` 实例，在 `build()` 中初始化，在 `ref.onDispose` 中释放
- 同一个 Notifier 可以同时使用 `AsyncRequestHandler`（请求管理）和 `PaginatedListHandler`（分页管理），互不冲突
- 不需要请求管理的 Notifier（如 `MainShell` 曾经只需要管理 Tab 下标）可以完全不创建处理器

```dart
// 按需组合，而非强制性继承
class HomeNotifier extends Notifier<HomeState> {
  late final _handler = AsyncRequestHandler();    // 需要

  @override HomeState build() {
    ref.onDispose(() => _handler.dispose());
    return const HomeState();
  }
}
```

### 12.2 回调注入：打破 ApiClient 和 AuthProvider 之间的循环依赖

网络层和认证层之间存在天然的循环依赖：
- `ApiClient` 每次请求需要 token → 需要知道当前登录状态
- `AuthProvider` 登录/退出时调用 `ApiClient` → 需要网络层

传统做法是引入中间接口或事件总线，但本项目用了更轻量的方案：**回调注入**。

在 `AuthNotifier.build()` 中：

```dart
final apiClient = ref.read(apiClientProvider);
apiClient.setTokenProvider(() => state.token);
apiClient.setUnauthorizedCallback(logout);
```

ApiClient 不导入 AuthProvider；AuthNotifier 通过 Riverpod 获取 ApiClient，不绕开依赖注入。Token 在**每次请求时**延迟读取（闭包捕获 `this`，每次返回最新的 `state.token`），因此登录/退出后不需要重建 Dio 实例。

### 12.3 401 并发保护：UnauthorizedGuard

这是一个每个团队最终都会遇到的 bug：三个并发请求同时返回 401 → 三次触发退出登录 → 三次导航到登录页 → 页面栈混乱。

`UnauthorizedGuard` 用一个简单的门控解决：只有一个 401 能通过；后续的 401 被静默丢弃，直到用户重新登录后调用 `reset()`。`handle()` 会等待异步 `logout()` 完成，确保安全存储和本地用户信息完成清理；清理异常统一记录日志。

```dart
// auth_provider.dart — 登录成功后重置守卫
ref.read(apiClientProvider).resetUnauthorizedGuard();
```

### 12.4 StatefulShellRoute：消除一整个 ViewModel

在本项目的早期版本中，`MainShell` 有一个专门的 `MainViewModel` 来管理 `tabIndex`。迁移到 `StatefulShellRoute.indexedStack` 后，这个 ViewModel 被完全移除。

GoRouter 的 `StatefulNavigationShell` 负责：
- 记录当前选中的 Tab 分支
- 管理每个分支独立的导航栈（Android 返回键在 Tab 内正确回退）
- 保证 Tab 切换时子页面不被销毁（内建 `IndexedStack` 语义）

这消除了一个只存 `int` 的 ViewModel 类——它本质上是"路由状态"，不应该由业务 ViewModel 管理。

### 12.5 不可变状态：Riverpod 的脏检查优化

每个 Notifier 的状态类都是不可变的，更新通过 `copyWith` 创建新对象：

```dart
state = state.copyWith(viewState: ViewState.loading);
```

这不仅仅是一种风格偏好。Riverpod 3 统一使用 `==` 判断 Provider 是否需要通知监听者。当前手写 State 没有重写 `==`，所以 `copyWith` 创建的新对象会触发 rebuild；如果以后实现值相等，相同值的新状态可能不会通知 UI。不要直接修改旧 State 或其集合字段。

### 12.6 拦截器链的顺序有讲究

`ApiClient._resetInterceptors` 中拦截器的添加顺序决定了请求/响应的处理流程：

```text
请求方向（按添加顺序执行）→
  TokenInterceptor      — 注入 Authorization header
  AppLogInterceptor     — 打印请求方法、URL 和状态码（不记录 token/请求体）
  UnauthorizedInterceptor — 检测 401 响应
  RetryInterceptor      — 对允许重试的临时网络异常执行退避重试
← 响应方向（按添加逆序执行）
```

每个拦截器的位置都有原因：
- **Token 在最前**：请求发出前统一注入最新认证信息
- **日志不记录敏感数据**：避免 token、密码和业务请求体进入调试日志
- **401 独立处理**：未授权响应只触发一次异步退出，不进入网络重试
- **重试限制方法**：GET、HEAD 默认可重试；POST、PUT、DELETE 和上传默认不重试，只有显式设置 `allowRetry` 才允许重试
- **取消优先**：页面销毁或 CancelToken 已取消时，即使处于退避等待也不会重新发起请求

### 12.7 测试边界就是架构边界

ViewModel 测试**只测业务逻辑**，Repository 测试**只测数据转换**——这个边界不是随意画的，而是由依赖倒置（Repository 接口）和 `ProviderContainer.overrides` 精确实现的：

- ViewModel 测试通过 `overrides` 替换 `RepositoryProvider`，不碰网络
- Repository 测试通过 `overrides` 替换 `ApiService`，不发起真实请求
- Widget 测试包裹 `ProviderScope`，使用与生产代码完全相同的 Provider 创建路径

如果你发现测试某个 Notifier 时需要 mock 三层以上的依赖，那说明这个 Notifier 的职责太多了——这是**架构在测试端的反馈信号**。

### 12.8 Mock 开关是编译时优化，不是运行时判断

`EnvConfig.enableMock` 使用 `bool.fromEnvironment` 而非普通 `bool`。这意味着：

- 当 `--dart-define=ENV_ENABLE_MOCK=false` 时，`if (EnvConfig.enableMock)` 分支被编译器识别为死代码
- Dart 的摇树优化（tree shaking）在 release 构建中**完全移除** `_fetchMockBanners` 等方法
- 不会有多余的字符串常量、不会有 Mock 数据、不会有条件跳转指令

如果你需要一个运行时动态切换的开发面板，可以在此基础上再加一层。但编译时常量是"零成本抽象"的最佳实践。

### 12.9 ViewState 不是五个值，是一个状态机

`ViewState` 的五个枚举值之间存在明确的转移规则：

```text
idle ──→ loading ──→ success
                  ├──→ empty
                  └──→ error
error ──→ loading  （重试）
```

这些转移由 `AsyncRequestHandler.execute` 和 `PaginatedListHandler` 统一管理，不会在页面代码中散落状态切换逻辑。这意味着：
- 不会出现 `loading` 跳到 `loading` 的情况（防抖保护）
- 不会出现 `error` 状态下数据字段仍为旧值（`copyWith` 保证一致性）
- 新增页面时不需要重复实现这些转移规则

### 12.10 模型所有权与公共入口

模型是否被多个页面使用，不决定它必须进入 shared；先判断哪个业务领域拥有它。跨模块使用领域模型时，通过所属 feature 的公共入口导出。

| 模型 | 位置 | 原因 |
|------|------|------|
| `UserModel` | `features/auth/model/` | 表达登录会话中的用户，由 `auth.dart` 对外导出 |
| `HomeBanner` | `features/home/model/` | 只被 HomeNotifier 使用 |
| `LoginRequest` | `features/auth/model/` | 只被 LoginNotifier 使用 |
| `LoginResponse` | `features/auth/model/` | 只被 LoginNotifier 使用 |

**原则：先确定领域所有权，再决定公开范围。** 只有真正没有业务归属的通用数据结构才进入 shared；业务模型即使被多个 feature 消费，也继续由所属 feature 管理，并通过公共入口形成显式依赖。

---

## 13. 开发约定（与第 12 节配合阅读）

为了让项目长期保持清晰，请遵守这些约定：

- View 不直接调用 Dio。
- View 不直接调用 Repository。
- ViewModel 不直接创建 Dio。
- Repository 不依赖 `BuildContext`。
- App 级状态仍按领域归属放置，例如会话在 `features/auth`、主题在 `shared/theme`。
- 业务状态放各自模块的 ViewModel。
- 纯基础设施放 `core/`，可复用的 UI/状态工具放 `shared/`。
- 跨模块复用组件放 `shared/`。
- 新业务模块优先按 `model / repository / view_model / view` 拆分，并在 feature 根目录维护公共入口和 Repository Provider。
- 使用 `ViewState` 的页面优先用 `PageShell + StateView`；直接消费 Riverpod 异步 Provider 时优先用 `AsyncValue.when`。
- 字符串优先放到 `AppStrings`。
- 间距优先使用 `AppSpacing`。
- 圆角优先使用 `AppRadius`。
- ViewModel 和 Repository 通过 Riverpod Provider 注册和获取（`ref.read`/`ref.watch`）。
- 单元测试中通过 `ProviderContainer` + `overrides` 替换依赖。

后续维护 README 时，至少同步检查四处：顶部“推荐阅读顺序”、第 1 节真实目录和依赖边界、第 6 节模块说明、第 10 节测试入口。新增 feature 时记录公共入口、Repository Provider 归属、数据来源和生命周期；不要只记录页面名称。

## 14. 一句话理解这个架构

这个项目的核心思想是：

```text
Riverpod 管全局状态、依赖注入和页面刷新，
Notifier（ViewModel）管页面状态和业务流程，
Repository 管数据来源和数据转换（Mock / 真实 API 自动切换），
ApiClient 管网络请求和异常处理，
GoRouter 管 StatefulShellRoute Tab 路由和登录拦截。
```

只要后续开发遵守这个数据流，项目规模变大后依然能保持清晰、可测试、可维护。
