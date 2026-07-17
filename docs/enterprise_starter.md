# 企业项目启动指南

这份文档只讲“如何把当前仓库用作一个新的企业 Flutter 项目底座”。完整架构入口见根目录
[README.md](../README.md)；Riverpod API 的可运行案例由独立示例应用自行维护。

## 1. 底座边界

底座已经提供：

- Riverpod 3 依赖注入、App 级状态与 MVVM 业务状态组织方式。
- 只在跨 Repository/全局状态编排时使用的 Application 用例层，以及通过抽象端口连接实现的示例。
- GoRouter 登录守卫、安全深链回跳、可注入业务路由包和可整体删除的 Starter 组件。
- 首帧前关键启动、首帧后后台预热、失败重试与配置阻断。
- Dio 抽象、响应协议适配、请求 ID、幂等键、重试、取消、上传下载与系统网络连接监听。
- 完整会话安全存储、旧会话迁移、可插拔刷新令牌、并发 401 单次刷新与失败退出。
- SQLite 迁移、可注入普通偏好、安全存储、网络状态、权限和 App 信息抽象。
- AppFailure 统一异常分类、根因/堆栈保留、安全用户提示与低噪音非致命上报。
- 可替换日志、崩溃与性能上报后端、ARB 国际化入口，以及支持上/中/下位置的公共 AppToast 和带操作的 AppSnackBar。
- 模块依赖、MVVM 分层和循环依赖自动检查、覆盖率门禁与 GitHub Actions CI。

底座刻意不预设：

- 具体公司的 UI 品牌、埋点平台、推送平台、地图、支付和即时通讯。
- 通用“万能 BaseRepository / BaseViewModel / BasePage”。业务差异大时，这类继承通常制造耦合。
- 所有企业都不需要的微服务 SDK、动态化、插件化或复杂多包工程。

这些能力应在真实需求出现后，通过现有接口和 Provider 注入，而不是提前塞进 core。

## 2. 创建新项目

在仓库根目录先预览：

```bash
dart run tool/bootstrap.dart \
  --name acme_console \
  --display-name "Acme Console" \
  --organization com.acme \
  --mode production \
  --dry-run
```

确认后去掉 `--dry-run`。工具会同步处理：

- `pubspec.yaml` 包名和描述。
- 所有 `package:<old-name>/` import。
- Android namespace、applicationId、Manifest 显示名和 MainActivity 包目录。
- iOS bundle identifier、显示名和 bundle name。
- SQLite 数据库文件名。
- `config/local.json` 初始环境文件。

执行完成后：

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

不要重复运行初始化工具。若第一次使用了 `--mode production`，必须先替换
`config/local.json` 中的占位 API 地址，否则启动校验会按设计阻断 App。

## 3. 启动任务放置规则

底座没有在 `main()` 中串行初始化所有 SDK。启动分成六种时机：

| 时机 | 适合内容 | 现有入口 |
| --- | --- | --- |
| runApp 前 | Engine 绑定、日志配置、全局异常入口 | `runApplication` |
| 创建业务 ProviderScope 前 | 环境安全校验、Provider 立即依赖的最小存储 | `AppBootstrap` |
| 创建 MyApp 前 | 恢复隐私版本；首次无记录时清除残留安全会话 | `PrivacyConsentGate` |
| 业务 Navigator 上方 | 首次自动授权、登录再次触发与任意页面政策升级的统一覆盖 | `PrivacyConsentHost` |
| 登录请求发出前 | 读取协议勾选状态，未勾选时请求弹窗并阻止越过授权 | `requestPrivacyConsentBeforeLogin` |
| MyApp 第一帧后 | 崩溃监控等需要尽早工作的旁路能力 | `AppWarmupPhase.afterFirstFrame` |
| 会话恢复和目标页首帧后 | 远程配置、更新检查、统计 SDK | `AppWarmupPhase.afterSessionReady` |
| 第一次使用 | SQLite、地图、支付等功能专用重能力 | 对应 Provider |

`AppWarmupTask.phase` 决定任务在哪个阶段运行；同一阶段只执行一次，阶段内任务彼此独立并行。失败只记录
`AppWarmupIssue`，不能把已经显示的登录页或首页切回错误页。
任务注册表的项目组装逻辑如果抛错，会被记录为 `registry.<phase>` 并正常结束加载，不会让预热状态永久
停在 `AsyncLoading`；这不代表可以忽略配置错误，监控与测试仍应处理对应 issue。
两个 Warmup 阶段还会等待当前隐私政策版本被同意；政策升级弹窗未处理或已拒绝时，尚未开始的任务不会运行。
SQLite 由 `appDatabaseProvider` 延迟到第一次 CRUD，完全不用数据库的项目不会增加这段启动耗时。

项目级 Provider 替换从统一入口传入：

```dart
Future<void> main() {
  return runApplication(
    createProjectRouteBundle(),
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

这样每个项目只修改组合入口，不需要改 `AppRouter`、`ApiClient` 或通用 Provider 的内部实现。

## 4. 环境与安全

环境模板位于 `config/`：

| 文件 | 用途 | Mock |
| --- | --- | --- |
| `development.json` | 本地开发 | 开启 |
| `testing.json` | 测试服务联调 | 关闭 |
| `staging.json` | 验收环境模板 | 关闭，API 必须替换 |
| `production.example.json` | 生产模板 | 关闭，复制后使用 |
| `local.json` | 每位开发者的本地覆盖 | Git 忽略 |

运行：

```bash
flutter run --dart-define-from-file=config/local.json
```

production 环境或任意 release 构建会强制检查：

- API 必须是 HTTPS 且不能是 `example.com` / `.invalid` 占位地址。
- Mock、调试日志、Charles 和坏证书放行必须关闭。
- App 名和 API URL 必须有效。

dart-define 不是秘密存储。API secret、私钥和固定访问令牌不能放进 JSON 或 Dart 代码，应由后端交换、
系统安全存储或 CI secret 提供。

## 5. 接入正式业务

根项目本身就是纯企业底座，不需要先运行清理脚本。推荐先用 `tool/bootstrap.dart` 完成包名、
平台标识和数据库文件名初始化，再创建第一个真实 feature。

接入第一个真实模块时：

1. 创建 `lib/features/<feature>/`。
2. 保持 `model / repository / view_model / view` 数据流。
3. 在 `<feature>.dart` 只导出 App 或其他模块真正需要的公开 API。
4. 创建项目自己的路径类和 `AppRouteBundle`，在路由包中通过公共入口组装页面。
5. 在 `main.dart` 把 `createStarterRouteBundle()` 换成项目路由包；不要修改通用 `AppRouter`。
6. 编译通过后删除 `lib/app/starter/` 和它自己的 `test/app/starter/`；其他底座文件与通用测试无需清理引用。

`authenticatedHome` 会被认证守卫自动保护。其他路由树按需加入 `protectedPaths` 或
`protectedPrefixes`。用户从通知打开内部深链时，守卫会在会话恢复/登录期间保存安全 `returnTo`，成功后
回到原 path、query 和 fragment；外部 URL 不会被接受为回跳目标。

跨 feature 依赖必须导入目标模块的 `<feature>.dart`，不能进入其内部目录。架构测试会同时检测分层越界
和 feature 循环依赖。

现有 Auth 展示了“一个领域内部出现多条完整能力后怎样继续拆分”：`auth/login` 保存登录页面、状态、用例和
接口，`auth/session` 保存全局认证状态、安全存储、刷新与网络绑定，根目录只保留公共入口和跨切片组合。
Login 通过 SessionActivator 单向调用 Session，Session 不知道 Login。新模块只有一条简单流程时不必照搬
两级目录；当订单模块同时出现列表、建单、审核等多条独立流程时，再采用相同的内部业务切片方式。

## 6. 后端协议接入

Repository 只依赖 `ApiService`。项目默认的 `EnvelopeResponseAdapter` 支持
`{code, message, data}`，同时允许普通 Map / List 直接作为业务数据。

纯 REST 后端通过 `runApplication(rootBuilder: ...)` 中的 ProviderScope 替换：

```dart
responseAdapterProvider.overrideWithValue(const DirectResponseAdapter())
```

协议字段不同则实现 `ResponseAdapter`：

```dart
class ProjectResponseAdapter implements ResponseAdapter {
  const ProjectResponseAdapter();

  @override
  ApiResponse<T> adapt<T>(
    Response<dynamic> response,
    T Function(dynamic json)? decoder,
  ) {
    // 只在这里解释项目后端协议。
    throw UnimplementedError();
  }
}
```

不要在每个 Repository 重复判断 `code`，也不要让页面捕获 DioException。

每个请求都可传 `RequestContext`：

```dart
final result = await apiService.post<Order>(
  OrderEndpoints.create,
  data: request.toJson(),
  cancelToken: cancelToken,
  context: const RequestContext(
    idempotencyKey: 'create-order-unique-id',
    allowRetry: true,
    replayPolicy: RequestReplayPolicy.never,
  ),
  fromJson: (json) => Order.fromJson(json as Map<String, dynamic>),
);
```

写操作只有在后端支持幂等键时才应打开网络重试。支付、建单等敏感写操作即使刷新 Token 成功，也不应
自动重放，所以同时设置 `RequestReplayPolicy.never`。上传下载由底座强制禁止重放。页面或 Provider 销毁时
应取消同一次请求的 `RequestCancellationToken`。Dio `CancelToken` 只在 ApiClient 内部适配，不能出现在
Repository、Application、ViewModel 或 View 中。

`allowRetry: true` 与非空 `idempotencyKey` 对写请求缺一不可。底座组合测试会让请求真实经过 Token、401、
重放和 Retry 拦截器，验证并发 401 只刷新一次、晚到的旧 Token 请求复用新 Token、never 请求不重放，以及
幂等写请求重试时 key 保持不变。新增签名或缓存拦截器后，也应把它加入组合测试，不要只测孤立方法。

缓存也必须由业务显式选择：短时复用使用 `MemoryCachePolicy<T>`；需要跨重启保留的非敏感 JSON 快照使用
`DatabaseCachePolicy<T>`。后者默认不注册 Provider、不自动缓存请求。cacheKey 含用户数据时必须加入
tenantId/userId；Token、密码仍使用安全存储；复杂离线领域数据建立独立表，不要把 `app_cache` 当万能数据库。

## 7. 会话刷新

默认 `DisabledSessionRefresher` 不假设后端具有 refresh token，401 会安全退出。真实项目实现：

```dart
class ProjectSessionRefresher implements SessionRefresher {
  ProjectSessionRefresher(this.authApi);

  final AuthApi authApi;

  @override
  Future<String?> refreshAccessToken() async {
    final session = await authApi.refresh();
    return session.accessToken;
  }
}
```

然后在 `runApplication` 的 `rootBuilder` 中替换 `sessionRefresherProvider`。刷新请求建议使用独立、没有
`UnauthorizedInterceptor` 的客户端，避免刷新接口自身 401 时递归。

`TokenRefreshCoordinator` 保证一批并发 401 共享一个刷新 Future；成功后原请求只重放一次，仍然 401
或刷新失败才进入 `UnauthorizedGuard` 清理会话。

`AuthSession` 把 token 与用户作为一个 JSON 写入系统安全存储，写成功后才发布已登录状态。底座保留一次
旧版 `auth_token + current_user` 迁移，迁移成功或退出登录后会清除旧数据。新项目不要再用
SharedPreferences 保存 token，也不要在登录页源码中放默认账号或密码。

恢复、登录、刷新和退出共用串行存储队列与会话版本号。这样用户退出后，尚未完成的刷新不能把旧账号重新
写回；新的登录也不会被迟到的启动恢复覆盖。普通退出在内存中立即生效并重试持久清理一次；政策升级拒绝
采用严格清理，Keychain/Keystore 连续失败时保留遮挡弹窗并允许用户重试。

## 8. 普通偏好、插件边界与异常链路

业务代码通过 `preferencesStoreProvider` 获取 `PreferencesStore`，不要直接调用静态 `LocalStorage`。
`LocalStorage` 只负责 Bootstrap 前初始化 SharedPreferences，`BootstrappedPreferencesStore` 是默认适配器。
测试可以 override 内存实现；企业项目也可以替换成自己的配置存储，而不修改主题或认证迁移代码。

架构测试把现有基础设施插件限制在明确目录：Dio、SQLite、SharedPreferences、安全存储、连接状态、权限、
包信息和图片缓存都不能进入 Repository、Application、ViewModel、View 或独立 Demo。增加新的平台插件时，
先创建稳定 Service/Repository 端口和单一适配目录，再把该目录加入白名单；不要直接放宽到整个 core。

插件边界统一抛 `AppFailure`：网络、协议、数据库、安全存储和其他平台服务都会保留原始 cause/stack。
`FailureMessageResolver` 负责用户提示，`FailureObserver` 负责监控筛选。网络断开、业务拒绝和取消不会上报；
存储、协议和未知平台故障会上报根因。两者职责不能合并，否则容易把技术信息展示给用户或制造告警风暴。

## 9. 日志、监控与隐私

`AppLogger`、`CrashReporter` 和 `AppPerformance` 是稳定入口。接入 Sentry、Firebase Crashlytics、
Datadog 或公司平台时，实现 `LogSink`、`CrashReportingBackend`、`PerformanceReporter`，通过
`runApplication` 参数注入；SDK 的耗时初始化仍由对应阶段的 AppWarmup 调用。

隐私同意使用结构化记录而不是 `isFirstLaunch`。没有历史记录时，`PrivacyConsentGate` 先清理可能残留的安全
会话，再创建 MyApp 并直接显示登录页。认证恢复确认未登录后，PrivacyConsentHost 自动显示一次首次弹窗；
拒绝后本次运行不再自动重复。默认 LoginPage 展示协议复选框，在未勾选并点击登录时调用
`requestPrivacyConsentBeforeLogin`，防止拒绝后直接提交；自定义 SSO/短信登录页替换默认 `loginBuilder` 后，
也必须把自己的复选框值通过 `agreementSelected` 传给该函数。

授权事实只有一个状态源：无历史版本、旧版本、当前版本分别恢复为首次授权、政策升级、已授权，三个状态互斥。
`PrivacyPromptCoordinator` 只负责弹窗请求互斥和登录 Future 结果，`PrivacyConsentHost` 是唯一 DialogRoute
Presenter；登录页不再创建 showDialog。这条规则同时
覆盖“用户第一次登录，但安装的新版本正好升级了隐私政策”的边界，不会出现两层 Dialog。

存在旧版本时由 `PrivacyConsentHost` 在业务 Navigator 上方弹出升级说明：同意后保留当前路由；拒绝时保持
弹窗遮挡，等待退出登录和安全存储清理完成后再关闭；清理重试后仍失败会保留弹窗并提示重试。本次进程不重复
弹出，下次启动继续提醒。普通退出登录不删除同意记录。首次拒绝不再
主动终止 Android 或 iOS 进程，因此底座没有隐私专用 MethodChannel；两端都只关闭弹窗并留在登录页。项目
接入时必须同时替换 `ENV_PRIVACY_POLICY_URL`、`ENV_USER_AGREEMENT_URL`、授权版本
`ENV_PRIVACY_POLICY_VERSION`、两份正文版本 `ENV_PRIVACY_POLICY_DOCUMENT_VERSION` 与
`ENV_USER_AGREEMENT_DOCUMENT_VERSION`、显著告知文案和完整正文。两个文档入口由用户主动点击后
交给系统浏览器，不在同意 Dialog 上再叠一个占位弹窗。

Flutter 门禁无法阻止厂商 SDK 的原生自动初始化。接入推送、统计、广告、地图或风控 SDK 时，应检查
Android ContentProvider/Application 和 iOS AppDelegate，关闭默认自动启动，再把手动 initialize 放到同意
后的 Warmup 或对应按需 Provider。

网络日志默认不记录 Header、请求体、响应体、Query、Fragment 和 URL 用户信息，只记录方法、安全路径、
状态码和 requestId。扩展日志时仍应过滤：

- token、cookie、密码、验证码和身份证号。
- 请求/响应中的个人信息。
- 数据库完整记录和文件路径中的用户信息。

`BootstrapResult` 可用于上报“ready / degraded / failed”以及关键启动失败阶段；首帧后任务的结果读取
`appWarmupProvider`，两类问题不要混成同一个启动状态。

性能门面已经记录 Bootstrap、Warmup、SQLite 首次打开、网络请求和 Flutter 帧耗时。指标 attributes 只能放
方法、路径、状态码等低基数字段，不能放用户 id、订单号、完整 URL；性能 SDK 抛错会被隔离，不会打断业务。

## 10. 本地化

正式文案写入 `lib/l10n/app_zh.arb`、`app_en.arb`，页面通过
`AppLocalizations.of(context)` 读取。ViewModel 没有 `BuildContext` 时，不保存已经翻译好的中文 String，
而是发布 `UserMessage.localized(UserMessageKey.xxx)`；View 收到后再用当前 `AppLocalizations` 解析。
后端明确标记为可展示的动态业务文案可使用 `UserMessage.text`，原始异常和技术信息不能直接展示。

修改 ARB 后执行：

```bash
flutter gen-l10n
```

## 11. 发布准备

Android 不再使用 debug key 签 release。复制 `android/key.properties.example` 为
`android/key.properties` 并填写本地或 CI 密钥；真实文件和 keystore 已被 Git 忽略。

网络权限必须保留在 `android/app/src/main/AndroidManifest.xml`，不能只写在 debug/profile Manifest，
否则 Release 包无法联网。相机、定位、相册等业务权限不要预置在底座；确定真实功能后再同时补 Android
Manifest、iOS Info.plist 权限说明和拒绝后的产品流程。

iOS 工程不写死开发团队，签名由 Xcode 或 CI 按项目配置。

发布前至少执行：

```bash
dart format --output=none --set-exit-if-changed lib test integration_test tool
dart run build_runner build
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart --minimum 70
dart run tool/privacy/privacy_audit.dart --mode development
flutter test integration_test -d <device-id> --dart-define-from-file=config/local.json
flutter build apk --release --dart-define-from-file=config/local.json
flutter build ios --release --no-codesign --dart-define-from-file=config/local.json
dart run tool/privacy/privacy_audit.dart --mode release \
  --environment-file config/local.json \
  --apk build/app/outputs/flutter-apk/app-release.apk
```

同时人工确认：

- production API、隐私政策、权限文案、图标、启动图和版本号。
- 使用默认 `lib/main.dart` 构建；Mock / 调试日志 / Charles 全部关闭。
- 数据库 migration 能从线上最老受支持版本升级。
- 登录过期、离线、连接超时、重复提交、应用切后台和低内存恢复路径。
- 崩溃、性能、接口 requestId 和关键业务埋点可在生产平台追踪。

## 12. CI 与合并门禁

`.github/workflows/ci.yml` 默认执行：

1. Flutter 3.44.0 安装与依赖恢复。
2. 隐私合规 development 审计，阻断未登记插件、权限和明确敏感 API。
3. Dart 格式校验。
4. build_runner 生成并检查仓库无差异。
5. `flutter analyze`。
6. `flutter test --coverage`，并执行 70% 最低覆盖率门禁。
7. Debug APK 构建。
8. 独立 Demo 的格式、生成代码、静态分析和测试；删除 Demo 目录后该 Job 自动跳过。
9. Android 模拟器运行关键 App 集成流程，并真实冒烟验证安全存储与 SQLite 迁移。

团队可在此基础上提高覆盖率阈值，增加 Sonar、依赖漏洞扫描、签名 release 构建与分发平台上传；这些步骤
依赖组织账号和密钥，因此不在通用底座中硬编码。

隐私审计规则和 SDK/权限/域名白名单位于 `compliance/privacy_audit.json`；真实项目发布前还要对最终
Release APK 执行严格模式。配置方法、动态调用观察和工具边界见
[开发阶段隐私合规自检](privacy_self_audit.md)。
