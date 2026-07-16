# Riverpod MVVM 企业 Flutter 底座

这个仓库分成两部分：

- 根目录是企业项目底座，只放新项目通常都会用到的能力。
- `examples/demo_app` 是独立学习应用，用来运行商品、订单和 Riverpod 教学案例。

两部分是单向依赖：Demo 依赖底座，底座不知道 Demo 的存在。因此正式 App 从根目录构建时，
不会编译 Demo 代码；不需要案例时，直接删除 `examples/demo_app` 即可。

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

启动流程分为三段，不是把所有 SDK 都塞进 `main()`。

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

### 第三段：首帧后预热，重能力按需初始化

`MyApp` 完成第一帧后调用 `appWarmupProvider.notifier.start()`。默认预热监控 SDK。远程配置、
更新检查等非关键任务也可以放进预热任务列表，并行执行；单个任务失败不会盖住首页。

SQLite 不属于预热。`appDatabaseProvider` 在 Repository 第一次执行 CRUD 时才打开数据库并运行迁移。
某个项目完全不用数据库，就不会为它支付启动耗时。

简单判断初始化应放哪里：

| 初始化内容 | 放置位置 |
| --- | --- |
| Flutter Engine 绑定、全局错误入口 | `runApplication` |
| 不完成就无法安全创建业务 Provider | `AppBootstrap` |
| 首页出现后可后台完成，且全 App 只做一次 | `AppWarmup` |
| 只有某项功能使用的数据库、地图、支付 SDK | 对应 Provider 第一次使用时按需初始化 |

不要为了看起来统一，就把所有初始化都放进 Bootstrap。启动编排的目标是时序清楚，不是任务越多越好。

项目级依赖在 `main.dart` 通过 overrides 注入，不要为换一个后端协议去修改通用启动代码：

```dart
Future<void> main() {
  return runApplication(
    createProjectRoutes(),
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
    starter/                登录后的最小落点，等待真实首页替换
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
  shared/
    errors/                 技术失败到安全提示文案的转换
    localization/           无 BuildContext 场景使用的少量通用文案
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
未完成 Dio 请求也会被 CancelToken 取消。

### watch、read、listen、select 的区别

| API | 什么时候用 | 例子 |
| --- | --- | --- |
| `ref.watch` | 当前对象要随依赖变化而更新 | 页面显示主题、Provider 创建 Repository |
| `ref.read` | 只执行一次命令，不订阅变化 | 点击按钮调用 `notifier.login()` |
| `ref.listen` | 状态变化时做一次副作用 | 通知路由器重新执行登录守卫、显示 SnackBar |
| `select` | 只关心 State 的一个小字段 | 只监听 `currentUser.id`，Token 变化时不重建 |

一个常见错误是在 `build` 中用 `read` 读取本应持续展示的状态。它不会订阅变化，界面自然不会更新。
另一个错误是在点击回调里用 `watch`；点击只是发送命令，用 `read(provider.notifier)` 更合适。

## 6. 一次登录请求的完整链路

以现有登录页为例：

1. `LoginPage` 用 `ref.watch(loginProvider)` 显示 loading、error 和按钮状态。
2. 点击按钮后用 `ref.read(loginProvider.notifier).login(...)` 发命令。
3. `LoginNotifier` 先校验表单，再调用 `LoginRepository`。
4. Repository 根据环境选择 Mock 或 `ApiService`，并透传 CancelToken。
5. `ApiClient` 加入 baseUrl、Token、requestId、重试和 401 处理。
6. `ResponseAdapter` 解释 `{code, message, data}`，Repository 把 data 转成 `LoginResponse`。
7. `LoginNotifier` 生成新 `LoginState`，页面自动刷新。
8. 页面把成功结果交给 App 级 `AuthNotifier`，后者把 Token 和用户组成一份 `AuthSession` 后原子保存。
9. `authProvider` 改变后，GoRouter 重新执行守卫并进入项目首页。

为什么登录分成 `LoginNotifier` 和 `AuthNotifier`？登录表单离开页面就可以销毁；用户会话要跨页面、跨路由
长期存在。把两者混在一起，会让全局状态背上验证码、密码错误、按钮 loading 等页面细节。

会话只写入系统安全存储的 `auth_session_v1`，不会再把 token 和用户分别写进两个存储，因而不会出现
“token 成功、用户失败”的半登录状态。由旧版升级时，`SecureSessionStore` 会在两份旧数据都完整时迁移一次，
写入新会话成功后删除旧 key；退出登录也会同时清理新旧凭据。登录页不在源码中预填案例账号或密码。

## 7. 请求取消与异步生命周期

`AsyncRequestHandler` 解决的是 Notifier 中反复出现的请求管理：防止重复提交、创建 CancelToken、
切换 ViewState、统一错误文案。它不是 ViewModel，不拥有业务 State。

页面销毁时有两道保护：

- `CancelToken` 尝试停止 Dio 的底层 IO，节省网络和解析工作。
- `ref.mounted` 防止一个已经完成、但所属 Notifier 已销毁的 Future 回写状态。

两者不能互相替代。缓存读取、普通 Future 未必支持 CancelToken，所以每次 `await` 后仍要检查生命周期。

列表分页使用 `PaginatedListHandler` 时传入 `readState`，让请求结束时读取最新 State，再合并服务器结果。
这样请求期间到达的 WebSocket 数据或乐观更新不会被旧快照覆盖；下拉刷新还会取消正在执行的加载更多。

## 8. 网络层怎样接真实后端

Repository 依赖 `ApiService`，不直接操作 Dio 实例、Options、Interceptor 或
DioException。为了让页面销毁真正中止 IO，接口目前仍公开 `CancelToken` 和进度回调；这是一处有意保留的
受控耦合，而不是“已经完全与 Dio 无关”：

```text
Repository
  -> ApiService
  -> ApiClient
  -> Dio Interceptors
  -> ResponseAdapter
  -> ApiResponse / AppFailure
```

底座已经包含：

- `RequestContext`：单次 Header、requestId、幂等键、重试和重放策略。
- `ResponseAdapter`：集中解释后端响应外壳。
- `TokenRefreshCoordinator`：一批并发 401 只刷新一次 Token。
- `SessionRefresher`：项目注入自己的 refresh token / SSO 实现。
- `AppFailure`：把稳定错误类型与底层 DioException 分开。

后端直接返回 REST 对象时，将 `responseAdapterProvider` 替换为 `DirectResponseAdapter`。后端字段是
`status/result/msg` 时，实现自己的 Adapter。不要在每个 Repository 重复判断业务 code。

写请求默认不自动重试。只有后端已经支持幂等键，并且请求提供稳定 `idempotencyKey` 时，才设置
`allowRetry: true`，否则可能重复创建订单或重复付款。

网络重试与 401 后重放是两件事。支付、创建订单等敏感操作应设置
`replayPolicy: RequestReplayPolicy.never`；上传和下载因为包含文件流，底座强制禁止自动重放。拦截器链只在
`ApiClient` 构造时创建一次，登录或退出只更新回调，不会在请求执行中清空拦截器。网络日志不记录 Header、
请求体、响应体、URL 用户信息、Query 或 Fragment；后端业务 message 默认也不会直接展示，项目确认其已脱敏
后才把 `EnvelopeResponseAdapter.trustBusinessMessage` 设为 true。

## 9. 新增第一个业务模块

例如新增工作台：

```text
lib/features/dashboard/
  dashboard.dart
  dashboard_providers.dart
  model/
  repository/
  view_model/
  view/
```

推荐步骤：

1. 先写 Model 和 Repository 接口。
2. 在 Repository 实现中调用 ApiService 或 DatabaseService。
3. 写不可变 State 和 Notifier。
4. 页面只 watch State、read Notifier 命令。
5. 在 `dashboard.dart` 只导出 App 组合层需要的类型。
6. 创建项目自己的 `AppRouteBundle`，不要把业务页面直接写回通用 `AppRouter`。

```dart
AppRouteBundle createProjectRoutes() {
  return AppRouteBundle(
    authenticatedHome: '/dashboard',
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

最后在 `main.dart` 把默认的 `AppRouteBundle.starter()` 替换为 `createProjectRoutes()`。

架构测试会检查：

- `core` 不能依赖 feature。
- `shared` 不能依赖 feature。
- feature 可以依赖 core、shared 和本模块。
- 跨 feature 只能导入目标模块的 `<feature>.dart` 公共入口。
- feature 之间不能形成循环依赖。
- Model、Repository、ViewModel、View 不能反向依赖。
- View/ViewModel 不能绕过 Repository 直接依赖 Dio、SQLite 或存储插件。

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

`StarterPage` 不是 Demo，它是底座登录后的最小落点。接入真实首页后，路由已经不会再进入它；是否删除
由项目决定，不影响 Demo 的独立性。

## 12. 注释怎么读，哪些文件不要手改

底座手写代码的注释主要回答这些问题：

- 这个类属于哪一层，拥有哪份状态。
- 为什么使用这种 Provider，生命周期到哪里结束。
- 一次请求或启动任务按什么顺序执行。
- 失败后是阻断、降级、重试还是忽略。
- 真实项目应该在哪个接口扩展，而不是修改底层实现。

简单的 `Padding`、`Text`、getter 不会逐行翻译语法。注释如果只是把代码再念一遍，会让真正重要的
并发和架构说明更难找到。

以下文件是生成代码，不要手工补注释或修改：

- `*.g.dart`：由 json_serializable / build_runner 生成。
- `lib/l10n/app_localizations*.dart`：由 ARB 和 `flutter gen-l10n` 生成。

应该修改 Model 注解或 `lib/l10n/*.arb`，然后重新生成。

## 13. 常见问题

### 启动后一直停在失败页

先看 `config/local.json`。production/release 最常见原因是 API 仍为占位地址，或 Mock、Charles、调试日志
没有关闭。Debug 控制台会保留原始 `ConfigurationException`。

### 登录后没有进入首页

检查项目路由包的 `authenticatedHome` 是否存在于 `routes`，以及受保护路径是否正确。登录页故意不写
`context.go`，导航由 auth 状态和路由守卫统一决定。

### 页面退出后请求还在跑

确认 Provider 使用合适的 `autoDispose`，`build()` 中注册了 Handler 的 `dispose()`，Repository 和
ApiService 每一层都透传了同一个 CancelToken。

### 修改状态后页面不刷新

确认页面使用 `watch`，并且 Notifier 创建了新的不可变 State。不要原地修改 List 或 State 字段。

### 数据库为什么启动时没有打开

这是按需初始化的结果。第一次通过 `DatabaseService` 执行 CRUD 时才会读取 `appDatabaseProvider.future`。
若初始化失败并希望重试，先 `ref.invalidate(appDatabaseProvider)`。

## 14. 提交前验证

```bash
flutter gen-l10n
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart --minimum 55
```

发布前再执行：

```bash
flutter build apk --release --dart-define-from-file=config/local.json
flutter build ios --release --no-codesign --dart-define-from-file=config/local.json
```

`.github/workflows/ci.yml` 会检查根底座与独立 Demo 的格式、生成代码、静态分析和测试；根测试覆盖率不能
低于 55%，并会构建 Android Debug APK。`android/app/src/main/AndroidManifest.xml` 中的 INTERNET 权限同时
覆盖 Debug、Profile 和 Release，避免开发包正常、正式包无法请求接口。
