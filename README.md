# Riverpod MVVM 企业 Flutter 底座

这个仓库分成两部分：

- 根目录是企业项目底座，只放新项目通常都会用到的能力。
- `examples/demo_app` 是独立学习应用，用来运行商品、订单和 Riverpod 教学案例。

两部分是单向依赖：Demo 依赖底座，底座不知道 Demo 的存在。因此正式 App 从根目录构建时，
不会编译 Demo 代码；不需要案例时，直接删除 `examples/demo_app` 即可。

## 大纲导航

第一次接触项目建议依次阅读 1～8；准备接入真实业务时重点阅读 9～11；维护底座或准备发布时阅读
12～14。点击下面的章节名称可以直接跳转：

- [先记住五个词](#先记住五个词)：先分清 View、ViewModel、Repository、Service 和 Provider。
- [1. 运行项目](#1-运行项目)：安装依赖、创建本地配置并启动 App。
- [2. 建议阅读顺序](#2-建议阅读顺序)：按照一条真实业务链路阅读代码。
- [3. App 打开后发生了什么](#3-app-打开后发生了什么)：理解 Bootstrap、会话恢复、路由和 Warmup。
- [4. 目录怎么读，代码应该放哪里](#4-目录怎么读代码应该放哪里)：掌握 app、core、shared、features 的依赖边界。
- [5. Riverpod 在本项目里怎样使用](#5-riverpod-在本项目里怎样使用)：Provider、Notifier、异步状态和 ref API。
- [6. 一次登录请求的完整链路](#6-一次登录请求的完整链路)：从 View 到接口、会话和路由的完整数据流。
- [7. 请求取消与异步生命周期](#7-请求取消与异步生命周期)：取消令牌、autoDispose 和 ref.mounted。
- [8. 网络层怎样接真实后端](#8-网络层怎样接真实后端)：响应协议、Token 刷新、重试、连接监听和公共 Toast。
- [9. 新增第一个业务模块](#9-新增第一个业务模块)：按照 MVVM 创建真实业务功能。
- [10. 初始化成自己的项目](#10-初始化成自己的项目)：使用脚本替换包名、应用名和环境配置。
- [11. Demo 会不会进入正式包，怎样删除](#11-demo-会不会进入正式包怎样删除)：删除 Demo 和 Starter 的最小步骤。
- [12. 注释怎么读，哪些文件不要手改](#12-注释怎么读哪些文件不要手改)：理解参数注释和生成代码边界。
- [13. 常见问题](#13-常见问题)：启动、登录、请求取消、状态刷新和数据库问题。
- [14. 提交前验证](#14-提交前验证)：格式、生成代码、分析、测试和发布构建命令。

配套文档：

- [启动、登录和首页完整流程](docs/startup_flow.md)
- [企业项目启动指南](docs/enterprise_starter.md)

## 先记住五个词

第一次读这套代码，不必先背 Riverpod 的所有 API。先分清下面五类对象：

| 名称 | 负责什么 | 不应该做什么 |
| --- | --- | --- |
| View | 展示界面、收集点击和输入 | 不直接请求接口，不直接操作数据库 |
| ViewModel | 保存页面状态、处理页面命令 | 不持有 `BuildContext`，不写具体 Dio 代码 |
| Repository | 决定数据从接口、缓存还是数据库获得，并转换 Model | 不控制 loading，不跳转页面 |
| Service | 封装 Dio、SQLite、权限、设备信息等技术能力 | 不包含某个页面的业务判断 |
| Provider | 创建、共享、监听和释放上面这些对象 | 不等于“把所有东西做成全局单例” |

一条常见数据流是：

```text
用户点击按钮
  -> View 调用 ViewModel
  -> ViewModel 调用 Repository
  -> Repository 调用 ApiService / DatabaseService
  -> Repository 把 JSON 转成 Model
  -> ViewModel 生成新的 State
  -> Riverpod 通知 View 重建
```

这就是本项目所说的 Riverpod + MVVM。Riverpod 管状态和依赖生命周期，MVVM 管每一层的职责。

## 1. 运行项目

项目当前基线：Flutter `3.44.x stable`、Dart `>=3.12.0 <4.0.0`、Riverpod `3.3.2`。

先安装依赖并创建本地环境配置：

```bash
flutter pub get
cp config/development.json config/local.json
flutter run --dart-define-from-file=config/local.json
```

`config/local.json` 不会提交到 Git。开发者可以各自填写 API 地址，不会互相覆盖。

如果要验证生产配置：

```bash
cp config/production.example.json config/local.json
```

然后把占位地址换成真实 HTTPS 地址。production 或 release 构建出现以下配置时，App 会停在
启动失败页，而不是带着危险配置继续运行：

- API 不是 HTTPS，或仍是 `example.com`、`.invalid` 占位地址。
- Mock、调试日志、Charles 代理仍然开启。
- 允许了不可信证书。

## 2. 建议阅读顺序

不要从 `lib` 第一行一路读到底。按一条真实链路读，理解会快很多：

| 顺序 | 先回答的问题 | 文件 |
| --- | --- | --- |
| 1 | App 从哪里启动 | `lib/main.dart`、`lib/app/bootstrap/run_application.dart` |
| 2 | 哪些初始化会阻塞首屏 | `app_bootstrap.dart`、`bootstrap_gate.dart`、`app_warmup.dart` |
| 3 | 登录态怎样恢复 | `auth_view_model.dart` |
| 4 | 登录态怎样控制路由 | `route_guard.dart`、`app_router.dart` |
| 5 | 登录按钮怎样发出请求 | `login_page.dart`、`login_view_model.dart`、`login_repository.dart` |
| 6 | 请求怎样进入 Dio | `api_service.dart`、`api_client.dart`、`dio_interceptor.dart` |
| 7 | 页面销毁怎样取消请求 | `async_request_handler.dart` |
| 8 | 模块边界怎样被检查 | `test/architecture/dependency_rules_test.dart` |

带着一个问题读一个文件即可。例如读 `LoginNotifier` 时，只看“输入怎样变成页面状态”；
Dio 拦截器的细节留到网络层再看。

## 3. App 打开后发生了什么

如果第一次阅读启动代码，建议同时打开
[启动、登录和首页是怎样连起来的](docs/startup_flow.md)，里面按实际跳转状态逐步展开。

启动流程分为四段。最重要的是分清：Bootstrap 不负责登录，`StarterHomePage` 也不是
启动页。正常冷启动的真实顺序如下：

```text
main
  -> runApplication
  -> BootstrapGate：配置校验、普通存储
  -> MyApp / GoRouter
  -> /session-restoring：读取安全会话
  -> 无会话：/login
  -> 有会话：原深链目标或 authenticatedHome
  -> 目标页面首帧后执行普通 Warmup
```

### 第一段：runApp 前，只做同步且必须的工作

```text
main
  -> runApplication
  -> WidgetsFlutterBinding.ensureInitialized
  -> 配置 AppLogger
  -> 注册 FlutterError / PlatformDispatcher 全局错误入口
  -> runApp(BootstrapGate)
```

这里不等待网络、数据库、监控 SDK。这样 Flutter 能尽快画出启动界面，避免长时间白屏。

### 第二段：启动门只等待关键任务

`BootstrapGate` 显示一个最小的 Material 页面，同时执行 `AppBootstrap`：

```text
环境安全校验
  -> LocalStorage 初始化
  -> 创建内层业务 ProviderScope
  -> 创建 MyApp
```

为什么内层业务 `ProviderScope` 不直接写在 `main.dart`？`themeProvider` 首次构建会同步读取普通存储，
旧版会话迁移也可能读取旧用户 JSON。Bootstrap 先尝试初始化 `LocalStorage`，再创建业务 Provider，才能让
首次主题和兼容迁移拿到可靠结果。项目通过 `rootBuilder` 提供的外层 ProviderScope 可以提前存在，因为
Provider 本身是惰性的，只要不要在 Bootstrap 完成前主动读取这些业务 Provider 即可。

环境配置不安全属于 `failed`，会阻止进入业务。LocalStorage 不可用属于 `degraded`：App 仍能使用
内存状态和系统主题，只是不能恢复普通偏好。原始异常会进入日志/监控，页面只显示安全提示。

### 第三段：恢复安全会话，再决定登录页或业务页

Bootstrap 放行后，`AuthNotifier` 才从 `SecureSessionStore` 读取 `auth_session_v1`。
GoRouter 的普通初始地址是 `/session-restoring`，因此不会先画出登录页再闪到首页：

- 没有会话：进入 `/login`。
- 有完整会话：进入 `authenticatedHome`。
- 从通知或外部链接进入：先保存内部 `returnTo`，恢复/登录后返回原 path、query 和 fragment。
- 原目标是公开页面：未登录也可以回到公开页面。

`authenticatedHome` 永远自动受登录保护；其他详情页通过 `protectedPaths` 或
`protectedPrefixes` 声明。`returnTo` 只接受 App 内部绝对路径，外部 URL 会被拒绝，避免开放重定向。

看到 App 直接进入 Starter，表示安全存储中已经存在上一次登录会话，不是跳过了登录逻辑。默认 Starter
首页提供“退出登录”，可验证“会话恢复 → 首页 → 退出 → 登录”的完整闭环。

### 第四段：分级预热，重能力按需初始化

`AppWarmupTask.phase` 明确任务时机：

- `afterFirstFrame`：MyApp 第一帧后执行。默认监控 SDK 使用这一阶段，尽早获得异常上报能力。
- `afterSessionReady`：会话恢复、目标页面画出一帧后执行。远程配置、更新检查和统计 SDK 默认使用这一阶段，
  避免与安全存储读取争抢启动期资源。

同一阶段只执行一次，阶段内任务并行；单个任务失败只记录问题，不会盖住登录页或首页。

SQLite 不属于预热。`appDatabaseProvider` 在 Repository 第一次执行 CRUD 时才打开数据库并运行迁移。
某个项目完全不用数据库，就不会为它支付启动耗时。

简单判断初始化应放哪里：

| 初始化内容 | 放置位置 |
| --- | --- |
| Flutter Engine 绑定、全局错误入口 | `runApplication` |
| 不完成就无法安全创建业务 Provider | `AppBootstrap` |
| 越早可用越好的非阻塞监控 | `AppWarmupPhase.afterFirstFrame` |
| 会话完成后才需要的全局任务 | `AppWarmupPhase.afterSessionReady` |
| 只有某项功能使用的数据库、地图、支付 SDK | 对应 Provider 第一次使用时按需初始化 |

不要为了看起来统一，就把所有初始化都放进 Bootstrap。启动编排的目标是时序清楚，不是任务越多越好。

项目级依赖在 `main.dart` 通过 overrides 注入，不要为换一个后端协议去修改通用启动代码：

```dart
Future<void> main() {
  return runApplication(
    createProjectRouteBundle(),
    crashReportingBackend: ProjectCrashBackend(),
    performanceReporter: ProjectPerformanceReporter(),
    rootBuilder: (child) => ProviderScope(
      overrides: [
        responseAdapterProvider.overrideWithValue(
          const ProjectResponseAdapter(),
        ),
        sessionRefresherProvider.overrideWith(
          (ref) => ProjectSessionRefresher(ref.watch(authApiProvider)),
        ),
      ],
      child: child,
    ),
  );
}
```

`crashReportingBackend`、`performanceReporter` 都是可选的稳定接口。具体 SDK 的对象在 `main()` 注入，
耗时的崩溃 SDK `initialize()` 仍由首帧后的 AppWarmup 执行。性能上报覆盖 Bootstrap、Warmup、数据库首次
打开、网络请求以及 Flutter 帧构建/光栅化；上报 SDK 自身失败不会打断业务。

## 4. 目录怎么读，代码应该放哪里

```text
lib/
  main.dart                 企业应用入口
  riverpod_mvvm.dart        外部壳或独立 Demo 使用的最小公开 API
  app/
    bootstrap/              启动关键路径、首帧后预热、启动失败页
    navigation/             路由器、登录守卫、业务路由组合契约
    starter/                可整体删除的登录后占位路由组件
  core/
    app/                    App 版本等平台信息
    cache/                  可替换缓存策略
    config/                 环境值与发布安全校验
    database/               SQLite 抽象、实现和迁移
    errors/                 跨层稳定失败类型
    network/                Dio、协议适配、重试、401 刷新
    performance/            启动、网络、数据库和帧耗时上报门面
    permission/             权限插件封装
    providers/              基础设施依赖注入
    storage/                普通偏好与系统安全存储适配器
    utils/                  日志、崩溃上报门面
  features/
    auth/                   正式认证和会话模块
      application/          只在跨 Repository/全局能力编排时使用的应用用例与端口
  shared/
    errors/                 技术失败到安全提示文案的转换
    localization/           ViewModel 消息键与按当前 Locale 解析的类型化消息
    navigation/             底座路径常量
    state/                  页面状态、请求处理、分页处理
    theme/                  主题、间距、圆角
    ui/                     没有业务归属的通用 Widget
```

新代码放置时可以按以下问题判断：

1. 它是不是某个业务独有？是，就放 `features/<业务>`。
2. 它是不是 Dio、数据库、权限这类技术能力？是，就放 `core`。
3. 它是不是多个业务都会使用，而且确实没有领域归属？是，才放 `shared`。
4. 它是不是只负责把模块、路由和全局对象装起来？是，放 `app`。

“两个页面都在用”不代表必须放 `shared`。例如用户模型属于认证领域，应保留在 `features/auth`，
其他模块通过 `auth.dart` 公共入口使用。

## 5. Riverpod 在本项目里怎样使用

### Provider：只读依赖或派生值

`service_providers.dart` 用 Provider 创建 ApiService、DatabaseService 等依赖。Provider 本身是惰性的，
没有代码读取它时不会创建对象。

```dart
final repositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(ref.watch(apiServiceProvider));
});
```

能从已有状态计算出来的值也用 Provider，不要再保存第二份可变状态：

```dart
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider.select((state) => state.currentUser?.id));
});
```

### NotifierProvider：同步状态加业务命令

`AuthNotifier` 持有全 App 登录态，`LoginNotifier` 持有登录页临时状态。Notifier 中更新的是不可变 State：

```dart
state = state.copyWith(viewState: ViewState.loading);
```

不要修改旧对象里的字段。创建新 State 后，Riverpod 才能可靠通知监听者。

### AsyncNotifierProvider：首次状态本身就来自异步任务

适合“进入页面立即加载详情，之后还能刷新、提交”的场景。`build()` 返回第一次数据，命令方法负责后续操作。
如果项目需要完整示例，可运行 `examples/demo_app` 中的异步课程。

### FutureProvider：一次异步值

本项目的 `appDatabaseProvider` 表达“最终会得到一个 Database”。调用方读取 `.future` 等待实例，Riverpod
负责缓存成功或失败结果。需要重试初始化时调用：

```dart
ref.invalidate(appDatabaseProvider);
```

### StreamProvider：连续事件

适合网络状态、WebSocket、数据库监听等持续变化的数据。事件源停止监听时，应配合 `autoDispose` 或
`ref.onDispose` 释放订阅。

### family：按参数隔离状态

订单详情 `orderId=1` 和 `orderId=2` 应是两份状态，使用 `.family`，不要让一个全局变量反复覆盖当前 id。

### autoDispose：没人使用就释放

`loginProvider` 离开登录页后不必保留，因此使用 `autoDispose`。它销毁时调用 Handler 的 `dispose()`，
未完成请求也会被底座自己的取消令牌中止。

### watch、read、listen、select 的区别

| API | 什么时候用 | 例子 |
| --- | --- | --- |
| `ref.watch` | 当前对象要随依赖变化而更新 | 页面显示主题、Provider 创建 Repository |
| `ref.read` | 只执行一次命令，不订阅变化 | 点击按钮调用 `notifier.login()` |
| `ref.listen` | 状态变化时做一次副作用 | 通知路由器重新执行登录守卫、显示 Toast/SnackBar |
| `select` | 只关心 State 的一个小字段 | 只监听 `currentUser.id`，Token 变化时不重建 |

一个常见错误是在 `build` 中用 `read` 读取本应持续展示的状态。它不会订阅变化，界面自然不会更新。
另一个错误是在点击回调里用 `watch`；点击只是发送命令，用 `read(provider.notifier)` 更合适。

## 6. 一次登录请求的完整链路

以现有登录页为例：

1. `LoginPage` 用 `ref.watch(loginProvider)` 显示 loading 和按钮状态，用 `ref.listen` 消费一次性 Toast。
2. 点击按钮后用 `ref.read(loginProvider.notifier).login(...)` 发命令。
3. `LoginNotifier` 先校验表单，再调用抽象的 `SignIn` 应用用例。
4. `SignInUseCase` 调用 `LoginRepository`；Repository 根据环境选择 Mock 或 `ApiService`，并透传
   `RequestCancellationToken`。
5. `ApiClient` 加入 baseUrl、Token、requestId、重试和 401 处理。
6. `ResponseAdapter` 解释 `{code, message, data}`，Repository 把 data 转成 `LoginResponse`。
7. `SignInUseCase` 把 Token 和用户组成一份 `AuthSession`，再交给抽象 `SessionActivator`。
8. App 级 `AuthNotifier` 实现该端口，原子保存会话并发布认证态；用例只返回稳定的 `SignInResult`。
9. 用例成功后 `LoginNotifier` 才把页面状态改为 success；保存失败则留在表单并发布提示。
10. `authProvider` 改变后，GoRouter 重新执行守卫并进入项目首页或安全的 `returnTo`。

这里特意不让 `LoginPage` 读取 `LoginState.token/user` 再调用 `AuthNotifier`。View 只收集输入并发送一条命令；
“请求成功后怎样保存会话、何时发布已登录状态”属于跨对象业务编排，放在 `SignInUseCase` 中完成。
`LoginNotifier` 只依赖 `SignIn` 抽象，不直接依赖 `AuthNotifier`、`SessionStore` 或 `ApiService`。

这里的三个对象各自只有一个变化原因：

- `LoginNotifier`：登录表单和页面状态变化时修改。
- `SignInUseCase`：完整登录业务步骤变化时修改。
- `AuthNotifier`：全局会话保存、恢复、刷新或退出规则变化时修改。

这不是给每个按钮机械增加 UseCase。只有一个命令需要协调多个 Repository、全局状态或事务顺序时，才增加
application 用例；普通“加载列表 → 展示结果”仍可由 ViewModel 直接调用单个 Repository。

登录表单的校验失败、接口失败和会话保存失败属于“可立即修改并重试”的操作结果，不会进入整页
`ErrorView`。`LoginNotifier` 发布类型化 `UserMessage` 和递增的 `feedbackId`，`LoginPage` 使用 `ref.listen`
消费一次性事件，再通过 `AppToast` 显示屏幕中部提示。即使连续两次错误文案相同，递增 id 也能确保
两次都提示；输入框不会被错误页替换。列表首次加载失败等阻断页面内容的错误，仍使用 `StateView`
和 `ErrorView`，两类场景不要混用。

固定错误在 ViewModel 中只保存 `UserMessageKey`，不会提前写死中文。View 真正展示时使用当前
`AppLocalizations` 解析中文或英文；只有后端明确标记可安全展示的动态业务提示才使用
`UserMessage.text(...)`。不要把 `error.toString()` 包装成动态提示。

会话只写入系统安全存储的 `auth_session_v1`，不会再把 token 和用户分别写进两个存储，因而不会出现
“token 成功、用户失败”的半登录状态。由旧版升级时，`SecureSessionStore` 会在两份旧数据都完整时迁移一次，
写入新会话成功后删除旧 key；退出登录也会同时清理新旧凭据。登录页不在源码中预填案例账号或密码。

## 7. 请求取消与异步生命周期

`AsyncRequestHandler` 解决的是 Notifier 中反复出现的请求管理：防止重复提交、创建取消令牌、
切换 ViewState、统一生成类型化错误消息。它不是 ViewModel，不拥有业务 State。

页面销毁时有两道保护：

- `RequestCancellationToken` 发出与网络库无关的取消信号，ApiClient 再把它转换为 Dio 的底层 IO 取消。
- `ref.mounted` 防止一个已经完成、但所属 Notifier 已销毁的 Future 回写状态。

两者不能互相替代。缓存读取、普通 Future 未必支持取消，所以每次 `await` 后仍要检查生命周期。

`RequestCancellationToken` 位于 `core/network/request_cancellation.dart`，但不 import Dio 或 Flutter。
Repository、Application、ViewModel 和独立 Demo 都只认识这个稳定类型。Dio `CancelToken` 只允许存在于
`core/network`，架构测试会阻止它再次渗透到业务层。未来替换 HTTP 客户端时，只改 ApiClient 的适配逻辑。

列表分页使用 `PaginatedListHandler` 时传入 `readState`，让请求结束时读取最新 State，再合并服务器结果。
这样请求期间到达的 WebSocket 数据或乐观更新不会被旧快照覆盖；下拉刷新还会取消正在执行的加载更多。

## 8. 网络层怎样接真实后端

Repository 依赖 `ApiService`，不直接操作 Dio 实例、Options、Interceptor 或 DioException。取消令牌与上传/
下载进度回调也由底座定义为纯 Dart 类型；ApiClient 是唯一把这些抽象翻译成 Dio 类型的适配边界：

```text
Repository
  -> ApiService
  -> ApiClient
  -> RequestCancellationToken 转 Dio CancelToken
  -> Dio Interceptors
  -> ResponseAdapter
  -> ApiResponse / AppFailure
```

底座已经包含：

- `RequestContext`：单次 Header、requestId、幂等键、重试和重放策略。
- `RequestCancellationToken`：跨 Repository/UseCase/ViewModel 的稳定取消协议。
- `ResponseAdapter`：集中解释后端响应外壳。
- `TokenRefreshCoordinator`：一批并发 401 只刷新一次 Token。
- `SessionRefresher`：项目注入自己的 refresh token / SSO 实现。
- `AppFailure`：把稳定错误类型与底层 DioException 分开。
- `FailureObserver`：只上报协议、存储和未知故障，过滤断网、取消和业务拒绝噪音。

后端直接返回 REST 对象时，将 `responseAdapterProvider` 替换为 `DirectResponseAdapter`。后端字段是
`status/result/msg` 时，实现自己的 Adapter。不要在每个 Repository 重复判断业务 code。

写请求默认不自动重试。只有后端已经支持幂等键，并且请求提供稳定 `idempotencyKey` 时，才设置
`allowRetry: true`。两个条件缺少任意一个，拦截器都不会重试，否则可能重复创建订单或重复付款。

网络重试与 401 后重放是两件事。支付、创建订单等敏感操作应设置
`replayPolicy: RequestReplayPolicy.never`；上传和下载因为包含文件流，底座强制禁止自动重放。拦截器链只在
`ApiClient` 构造时创建一次，登录或退出只更新回调，不会在请求执行中清空拦截器。网络日志不记录 Header、
请求体、响应体、URL 用户信息、Query 或 Fragment；后端业务 message 默认也不会直接展示，项目确认其已脱敏
后才把 `EnvelopeResponseAdapter.trustBusinessMessage` 设为 true。

并发 401 还有一个容易忽略的时序：第二个旧 Token 请求可能在第一次刷新完成后才进入拦截器。底座会比较
“失败请求携带的 Token”和“认证模块当前 Token”，如果当前已经更新，就直接使用新 Token 重放，不会再刷新
一次。组合测试真实经过 ApiClient 的完整拦截器链，覆盖并发单次刷新、旧请求重放、敏感请求禁止重放、写请求
缺少幂等键时不重试，以及带稳定幂等键时重试仍使用同一个 key。

### 异常怎样统一分类和上报

网络、SQLite、安全存储、权限、App 信息和网络状态插件都在各自适配器边界转换为 `AppFailure`。转换时保留
原始 `cause` 和 `stackTrace`，ViewModel 只看到稳定的 `FailureKind`；`FailureMessageResolver` 再生成安全、
可本地化的 `UserMessage`，不会把异常文本直接显示给用户。

`FailureObserver` 是统一监控出口：存储损坏、响应协议不匹配和未知平台故障会上报原始根因；断网、超时、
登录失效、权限拒绝、业务失败和主动取消属于可预期结果，不制造告警噪音。新增异步状态处理器时，应复用这个
出口，不能自行写一套“是否上报”的判断。

### 普通偏好怎样替换

`LocalStorage` 只留在 Bootstrap 和 SharedPreferences 适配器内部。主题、旧会话迁移和业务代码依赖
`PreferencesStore`，通过 `preferencesStoreProvider` 获取。测试或品牌壳可直接 override 成内存、加密偏好或
企业配置实现，不需要初始化插件全局状态。普通偏好不能存 Token；认证会话始终走 `SessionStore` 和系统安全
存储。`PreferencesStore` 也没有 `clear()`，避免一个模块误删其他模块的数据。

### 全局网络连接监听与临时错误恢复

`networkStatusProvider` 会先读取当前连接类型，再持续监听系统网络变化。`MyApp` 内部的
`AppNetworkFeedback` 只在以下情况提示：

- 首次查询就是离线，或在线切换到离线：提示检查网络设置。
- 离线重新变成在线：提示网络连接已恢复。

连接类型不等于互联网一定可用，因此底座不会因为 `connectivity_plus` 报告离线就直接拦截所有请求；
最终请求结果仍以 Dio 为准。底座也不会根据接口响应耗时推断“弱网”：慢响应可能来自服务器计算、数据库
或网关排队，把它提示成用户网络差会误导排查。确实需要网络质量探测的项目，应接入有明确产品指标和独立
探测目标的实现，不要复用普通业务接口耗时直接下结论。

临时网络错误恢复不是“所有请求都自动重试”。底座当前组合使用：连接/收发超时、GET/HEAD 临时错误有限重试、
1 秒/2 秒退避、写请求幂等白名单、页面销毁请求取消、Repository 缓存策略以及全局网络反馈。
支付、提交订单等非幂等操作仍然禁止自动重试，这是防止重复业务数据的安全边界。

### 缓存怎样按需选择

底座提供同一个 `CachePolicy<T>` 契约的两种实现：

- `MemoryCachePolicy<T>`：只在当前进程保存，适合几分钟内避免重复请求。
- `DatabaseCachePolicy<T>`：写入 SQLite `app_cache`，App 重启后仍存在，适合非敏感接口快照和字典。

两者都不会被底座自动注册或自动套在每个接口上。具体业务应在自己的组合 Provider 中决定是否启用：

```dart
final profileCacheProvider = Provider<CachePolicy<UserProfile>>((ref) {
  return DatabaseCachePolicy<UserProfile>(
    database: ref.watch(databaseServiceProvider),
    cacheKey: 'profile:$tenantId:$userId',
    duration: const Duration(minutes: 10),
    encode: (profile) => jsonEncode(profile.toJson()),
    decode: (value) => UserProfile.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    ),
  );
});
```

示例中的 `tenantId/userId` 不能省略，否则切换租户或账号时可能读取到其他用户缓存。Token、密码等敏感数据
不能放 `app_cache`，应使用 `SecureStorageService`。需要筛选、关联和事务的核心领域数据应建立独立数据库表；
`DatabaseCachePolicy` 只是可失效、可重新请求的快照，不是离线业务数据库，也不是通用离线写队列。

公共 Toast 位于 `lib/shared/ui/app_toast.dart`，所有 View 都可以统一调用：

```dart
import 'package:riverpod_mvvm/riverpod_mvvm.dart';

AppToast.showInfo(context, '已复制');
AppToast.showSuccess(context, '保存成功');
AppToast.showWarning(
  context,
  '资料即将过期',
  position: AppToastPosition.top,
);
AppToast.showError(
  context,
  '保存失败',
  position: AppToastPosition.bottom,
);
```

`AppToast` 使用根 `OverlayEntry`，默认 `AppToastPosition.center`，是真正覆盖在页面上的 Android 风格
短提示，不占用 Scaffold 的 SnackBar 通道。顶部适合网络状态，居中适合表单校验和普通结果，底部适合
不希望遮挡主要内容的短提示；三种位置都不会拦截页面点击。

Toast 是 View 层能力，不要在 Repository 或 ViewModel 中传入 `BuildContext`。ViewModel 应发布普通消息状态
或一次性事件，再由 View 使用 `ref.listen` 调用 `AppToast`。如果反馈需要“撤销、重试、查看”等按钮，使用
独立的 `AppSnackBar`：

```dart
AppSnackBar.show(
  context,
  message: '商品已删除',
  actionLabel: '撤销',
  onAction: restoreProduct,
);
```

必须确认或做选择时使用 Dialog；需要长期保留并阻断内容时使用页面内提示或 ErrorView。不要为了统一外观
把这些不同交互全部塞进 Toast。

## 9. 新增第一个业务模块

例如新增工作台：

```text
lib/features/dashboard/
  dashboard.dart
  dashboard_providers.dart
  application/             可选：只有跨多个边界的业务编排才创建
  model/
  repository/
  view_model/
  view/
```

推荐步骤：

1. 先写 Model 和 Repository 接口。
2. 在 Repository 实现中调用 ApiService 或 DatabaseService。
3. 若一个命令需要协调多个 Repository 或全局能力，增加 application 用例并依赖抽象端口；简单 CRUD 跳过。
4. 写不可变 State 和 Notifier，让 ViewModel 只管理页面状态与命令输入。
5. 页面只 watch State、read Notifier 命令。
6. 在 `dashboard.dart` 只导出 App 组合层需要的类型。
7. 创建项目自己的 `AppRouteBundle`，不要把业务页面直接写回通用 `AppRouter`。

```dart
AppRouteBundle createProjectRouteBundle() {
  return AppRouteBundle(
    authenticatedHome: '/dashboard',
    // 首页会被自动保护；这里保护 dashboard 下的其他详情页。
    protectedPrefixes: const ['/dashboard'],
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
    ],
  );
}
```

`AppRouteBundle` 这些参数分别解决不同问题：

| 参数 | 含义 | 工作台示例 |
| --- | --- | --- |
| `authenticatedHome` | 登录成功后最终进入的地址；必须有对应 `GoRoute.path`，并自动受登录保护 | `/dashboard` |
| `routes` | 项目真正注册到 GoRouter 的页面表 | Dashboard、订单、设置等路由 |
| `protectedPaths` | 必须登录的精确地址，只匹配完全相同的 path | `/settings` |
| `protectedPrefixes` | 必须登录的一组路由前缀，适合整个业务模块 | `/dashboard`、`/orders` |
| `loginPath` | 未登录时统一跳转的登录地址；通常沿用 `/login` | 不传 |
| `loginBuilder` | 项目需要替换底座登录页时提供的 Widget builder | SSO 登录页 |

这里传入的是 URI 的 `path`，不是完整 URL，也不包含 query。比如
`/orders/detail?id=100` 判断保护范围时使用 `/orders/detail`。`createProjectRouteBundle()` 是项目自己写的普通
函数，不是 Riverpod 或底座自动生成的 API；建议放在 `lib/project_routes.dart` 或项目 App 组合目录。
构造函数会立即拒绝外部 URL、带 query/fragment 的路径，并把路由和保护列表复制成不可变列表，避免启动后
被其他代码原地修改。

最后让 `main.dart` 改为导入项目路由并调用：

```dart
import 'app/bootstrap/run_application.dart';
import 'project_routes.dart';

Future<void> main() {
  return runApplication(createProjectRouteBundle());
}
```

确认编译通过后删除 `lib/app/starter/` 和它自己的 `test/app/starter/`。其他 MyApp、认证、路由和架构测试
使用独立测试路由，不依赖 Starter；架构测试也会阻止以后把 Starter 依赖重新写回通用底座。

架构测试会检查：

- `core` 不能依赖 feature。
- `shared` 不能依赖 feature。
- feature 可以依赖 core、shared 和本模块。
- 跨 feature 只能导入目标模块的 `<feature>.dart` 公共入口。
- feature 之间不能形成循环依赖。
- Model、Repository、ViewModel、View 不能反向依赖。
- Application 用例不能依赖 ViewModel/View；View 也不能绕过 ViewModel 直接调用用例。
- View/ViewModel 不能绕过 Repository 直接依赖 Dio、SQLite 或存储插件。
- Dio、SQLite、普通/安全存储、连接状态、权限、包信息和图片缓存插件只能出现在各自白名单适配目录；根业务
  与独立 Demo 都受同一条规则约束。

## 10. 初始化成自己的项目

先确保 Git 工作区可回退，然后预览脚本会改哪些文件：

```bash
dart run tool/bootstrap.dart \
  --name acme_console \
  --display-name "Acme Console" \
  --organization com.acme \
  --mode production \
  --dry-run
```

确认后去掉 `--dry-run`。脚本会处理：

- Dart 包名和 `package:` import。
- Android namespace、applicationId、显示名和 MainActivity 包目录。
- iOS bundle identifier、显示名和 bundle name。
- SQLite 文件名和 `config/local.json`。
- Demo 对根 package 的依赖名；不会修改 Demo 自己的 applicationId。

命令参数说明：

| 参数 | 是否必填 | 作用 |
| --- | --- | --- |
| `--name` | 是 | Dart 包名，也作为移动端 App ID 最后一段，如 `acme_console` |
| `--display-name` | 是 | 用户在桌面看到的名称，可以有空格或中文 |
| `--organization` | 是 | 反向域名前缀，如 `com.acme`，最终 App ID 为 `com.acme.acme_console` |
| `--mode` | 否 | `development` 默认开 Mock；`production` 生成必须替换的安全占位配置 |
| `--dry-run` | 否 | 只列出会修改的文件，不真正写入 |

脚本按“一次性初始化”设计，不要在同一项目反复执行。详细发布配置见
[企业项目启动指南](docs/enterprise_starter.md)。

## 11. Demo 会不会进入正式包，怎样删除

不会。`examples/demo_app` 有自己的 `pubspec.yaml`、入口、路由、页面和测试。依赖方向是：

```text
examples/demo_app  --->  根底座
根底座             -X->  examples/demo_app
```

正式项目不需要学习案例时：

```bash
rm -rf examples/demo_app
flutter pub get
flutter analyze
flutter test
```

根 `lib`、`pubspec.yaml`、测试、路由和 CI 都不需要跟着修改。CI 中的 Demo Job 检测不到 Demo pubspec 时
会自动跳过。正式 App 即使没有删除 Demo，根目录执行 `flutter build` 也不会编译它；删除只是为了让仓库
更干净。

`lib/app/starter` 也不是 Demo package，它是根底座第一次运行时使用的可拔插占位路由组件。接入真实首页后：

1. 将 `main.dart` 的 `app/starter/starter.dart` import 替换为项目路由文件。
2. 将 `createStarterRouteBundle()` 替换为 `createProjectRouteBundle()`。
3. 删除 `lib/app/starter/` 和对应的 `test/app/starter/`。

不需要修改 AppRouter、路由守卫、RoutePaths、认证模块或 CI。保留 Starter 时，正式构建会包含这个已注册的
占位路由；因此真实项目接入首页后推荐删除，而不是长期随正式 App 发布。Starter 的中英文占位文案也保存在
自己的 `starter_strings.dart`，没有写进全局 ARB，删除目录后生成的 AppLocalizations 不会残留占位字段。

## 12. 注释怎么读，哪些文件不要手改

底座手写代码的注释按“先职责、再参数、再流程、最后边界”组织，主要回答这些问题：

- 这个类属于哪一层，拥有哪份状态。
- 构造函数和方法的每个参数是谁传入的、null/默认值表示什么。
- 方法成功返回什么，取消、重复调用、Provider 销毁和异常时又返回什么。
- 为什么使用这种 Provider，生命周期到哪里结束。
- 一次请求或启动任务按什么顺序执行。
- 失败后是阻断、降级、重试还是忽略。
- 真实项目应该在哪个接口扩展，而不是修改底层实现。

阅读一个不认识的参数时，按下面顺序找：

1. 先看当前构造函数/方法上方的“参数说明”，确认它的业务含义和默认值。
2. 再看字段注释，确认它保存多久、是否敏感、是否允许为 null。
3. 参数属于回调或泛型时，看 typedef/接口注释，确认回调什么时候执行、返回值怎样解释。
4. 最后沿 Provider 查到创建位置，理解是谁注入了真实实现、测试怎样 override。

几个最容易误解的参数已经在源码中单独说明：

| 参数 | 所在文件 | 最重要的边界 |
| --- | --- | --- |
| `rootBuilder` | `run_application.dart` | 在启动门外包 ProviderScope/SDK Scope，不能提前读取依赖 LocalStorage 的业务 Provider |
| `stageTimeout` | `app_bootstrap.dart` | 单个关键启动阶段的上限，不是整个 App 的统一网络超时 |
| `authenticatedHome` | `app_route_bundle.dart` | 必须与 routes 中真实注册的首页 path 一致 |
| `allowRetry` | `request_context.dart` | 写请求还必须同时提供非空 idempotencyKey；它不等于允许 401 后重放 |
| `replayPolicy` | `request_context.dart` | 控制认证刷新后的原请求重放，支付、建单等敏感操作应设 never |
| `forceNeverReplay` | `api_client.dart` | 内部保护上传/下载流，调用方不能用 context 绕过 |
| `fromJson` | `api_service.dart` | 解析响应外壳中的 data，不是解析整个 Dio Response |
| `cacheKey` | `database_cache_policy.dart` | 持久化缓存唯一键；用户数据必须包含 tenantId/userId，防止串号 |
| `duration` | `database_cache_policy.dart` | 从成功写入开始计算的缓存有效期，必须大于 0 |
| `readState` | `paginated_handler.dart` | 异步结束时读取最新 State，防止覆盖实时推送或乐观更新 |
| `clearFeedbackMessage` | `login_view_model.dart` | 明确清除旧的一次性消息；普通 null 表示沿用旧值 |

简单 Widget 的布局语法和显而易见的常量不会逐行翻译；这类逐字注释会淹没真正需要理解的参数、生命周期、
并发和安全边界。类、公开方法、重要私有方法、回调、状态字段和可替换接口都应能从注释中读到“为什么这样设计”。

以下文件是生成代码，不要手工补注释或修改：

- `*.g.dart`：由 json_serializable / build_runner 生成。
- `lib/l10n/app_localizations*.dart`：由 ARB 和 `flutter gen-l10n` 生成。

应该修改 Model 注解或 `lib/l10n/*.arb`，然后重新生成。

## 13. 常见问题

### 启动后一直停在失败页

先看 `config/local.json`。production/release 最常见原因是 API 仍为占位地址，或 Mock、Charles、调试日志
没有关闭。Debug 控制台会保留原始 `ConfigurationException`。

### 登录后没有进入首页

检查项目路由包的 `authenticatedHome` 是否真实存在于 `routes`。首页会自动受保护；其他详情页检查
`protectedPaths/protectedPrefixes`。登录页故意不写 `context.go`，导航由 auth 状态、当前安全 returnTo 和
路由守卫统一决定。

### 页面退出后请求还在跑

确认 Provider 使用合适的 `autoDispose`，`build()` 中注册了 Handler 的 `dispose()`，Repository 和
ApiService 每一层都透传了同一个 `RequestCancellationToken`。不要在 Repository 中重新创建令牌，否则
页面取消的将不是正在执行的那一次请求。

### 修改状态后页面不刷新

确认页面使用 `watch`，并且 Notifier 创建了新的不可变 State。不要原地修改 List 或 State 字段。

### 数据库为什么启动时没有打开

这是按需初始化的结果。第一次通过 `DatabaseService` 执行 CRUD 时才会读取 `appDatabaseProvider.future`。
若初始化失败并希望重试，先 `ref.invalidate(appDatabaseProvider)`。

## 14. 提交前验证

```bash
flutter gen-l10n
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart --minimum 70
# 需要已启动的 Android/iOS 模拟器或真机
flutter test integration_test -d <device-id> --dart-define-from-file=config/local.json
```

发布前再执行：

```bash
flutter build apk --release --dart-define-from-file=config/local.json
flutter build ios --release --no-codesign --dart-define-from-file=config/local.json
```

`.github/workflows/ci.yml` 会检查根底座与独立 Demo 的格式、生成代码、静态分析和测试；根测试覆盖率不能
低于 70%，并会构建 Android Debug APK。单独的 Android 模拟器 Job 会运行全部 `integration_test`：既验证
“受保护地址 → 登录 → 会话保存 → 安全回跳”和“已有会话直接恢复首页”，也真实读写 Android 安全存储和
SQLite `app_cache` 表，尽早发现平台通道或数据库迁移问题。
`android/app/src/main/AndroidManifest.xml` 中的 INTERNET 权限同时覆盖 Debug、Profile 和 Release，避免
开发包正常、正式包无法请求接口。
