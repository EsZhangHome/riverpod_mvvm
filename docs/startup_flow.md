# 启动、登录和首页是怎样连起来的

这份文档只回答一个问题：从 `main()` 开始，为什么最后会看到登录页、Starter 首页或深链页面。

先记住：代码中同时存在两条链。

- Widget 创建链：决定哪些对象被创建。
- 路由状态链：根据登录态决定最终显示哪个页面。

`main()` 把路由包交给 `runApplication()`，不等于直接打开路由包里的首页。

## 1. main 只选择当前项目的路由组件

底座第一次运行时：

```dart
Future<void> main() {
  return runApplication(createStarterRouteBundle());
}
```

`createStarterRouteBundle()` 返回：

```text
登录后默认首页：/starter
业务路由表：/starter -> StarterHomePage
```

它表达的是“如果最终确认已经登录，默认去哪里”，不是“现在立刻打开 Starter”。

## 2. runApplication 只做同步运行时准备

`runApplication()` 按顺序完成：

```text
绑定 Flutter Engine
  -> 配置日志、崩溃和性能实现
  -> 注册 Flutter/Dart 全局异常入口
  -> runApp(BootstrapGate)
```

这里不读取 Token，不请求接口，不打开 SQLite，也不等待监控 SDK 初始化。这样 Flutter 可以尽快画出一个
可见页面，而不是让用户长时间停在原生启动图。

## 3. BootstrapGate 是首屏前关键启动门

`BootstrapGate` 先显示通用 LoadingView，同时执行 `AppBootstrap.initialize()`：

```text
检查环境配置
  -> 初始化 LocalStorage
  -> ready/degraded：创建 ProviderScope 和 PrivacyConsentGate
  -> failed：显示启动失败页
```

这里的 `LocalStorage` 只是 Bootstrap 使用的 SharedPreferences 初始化边界。业务 Provider 创建后，主题和
旧数据迁移都通过可替换的 `PreferencesStore` 访问普通偏好，不再直接依赖静态插件适配器。登录 Token 使用的
是后面的 `SecureSessionStore`，所以 Bootstrap 完成不代表用户已经登录。

Bootstrap 不处理数据库、首页接口、地图、支付和普通 SDK 预热。

## 4. 隐私状态区分首次登录授权和政策升级

门禁同步读取结构化 `privacy_consent_record_v1`（兼容旧的
`privacy_policy_accepted_version`），并把记录中的授权版本与本次构建的
`ENV_PRIVACY_POLICY_VERSION` 比较：

```text
没有历史版本   -> 先清除残留安全会话，创建 MyApp 并直接显示登录页
登录页显示完成 -> 显示协议复选框，不自动弹窗
未勾选点登录   -> 通过唯一 PrivacyConsentHost 显示协议弹窗
首次同意成功   -> 保存两份正文版本和 UTC 时间并选中；输入完整则续接登录，否则静默停留
首次拒绝       -> 不保存版本、取消选中并关闭弹窗，停留登录页
存在旧版本     -> 创建 MyApp，在当前路由上覆盖全局升级弹窗
升级同意成功   -> 关闭弹窗，不重建 Navigator，继续停留在原页面
升级拒绝       -> 保持弹窗遮挡，清除登录会话，由路由守卫返回登录页后再关闭
版本完全一致   -> 正常创建 MyApp
```

首次、升级、已授权由同一个状态机互斥恢复：没有版本只能是首次授权，有旧版本只能是升级，版本一致才放行。
因此“第一次登录但恰逢协议升级”只显示一个状态对应的弹窗，不会叠加。`PrivacyConsentHost` 是唯一
DialogRoute Presenter，`PrivacyPromptCoordinator` 负责登录等待结果和并发互斥；登录页自身不创建第二个
Dialog。首次拒绝不保存记录，下次冷启动仍保持未同意，但不会自动弹窗；再次点击登录仍会拦截。升级拒绝保留旧版本，下次启动也会
再次提示升级。普通退出登录不会清除隐私版本。

`ENV_PRIVACY_POLICY_DOCUMENT_VERSION` 与 `ENV_USER_AGREEMENT_DOCUMENT_VERSION` 用于追溯两份实际正文，
普通文字修订不触发重新同意；只有
`ENV_PRIVACY_POLICY_VERSION` 代表的授权范围发生实质变化时才弹升级提示。

首次授权前 MyApp 可以创建登录页、认证状态和路由，但默认 LoginPage 的提交前检查会请求唯一 Host 并阻止
登录接口真正发出；两个 AppWarmup 阶段也继续等待当前版本同意。政策升级需要保留当前路由，同样不会在弹窗
处理前启动尚未执行的敏感 Warmup。首次拒绝不杀进程，只关闭弹窗并停留登录页；Android 与 iOS 行为一致。

为什么首次同意还要清理安全会话：普通偏好和 Keychain/Keystore 的生命周期并不完全相同，尤其 iOS Keychain
可能跨卸载保留。如果隐私版本已不存在但 token 还在，不清理就可能直接恢复首页。BootstrapGate 通过
`onPrepareInitialLogin` 注入 SessionStore 清理；失败时显示重试页，不创建 MyApp，也不会恢复残留账号。

## 5. MyApp 创建稳定路由器

`MyApp` 创建一次 GoRouter，并把入口路由包交给它。普通冷启动地址固定为：

```text
/session-restoring
```

如果 App 是由通知或平台深链打开，GoRouter 会保留平台提供的内部地址。认证守卫在读取会话期间把这个地址
保存为安全 `returnTo`，不会直接丢到首页。

## 6. AuthNotifier 恢复安全会话

`authProvider` 第一次创建时先返回：

```dart
AuthState.restoring()
```

然后异步读取 `SecureSessionStore`：

```text
auth_session_v1 不存在或无效 -> AuthState.unauthenticated
auth_session_v1 完整有效       -> AuthState.authenticated
```

认证状态变化后，`ref.listenManual` 通知 GoRouter 重新执行 `AuthRouteGuard`。

## 7. 守卫怎样决定最终页面

普通启动没有 returnTo：

| 认证状态 | 最终页面 |
| --- | --- |
| restoring | `/session-restoring` |
| unauthenticated | `/login` |
| authenticated | `AppRouteBundle.authenticatedHome` |

因此底座直接进入 Starter 只表示安全存储里已有完整会话。Starter 页面提供退出按钮，调用
`AuthNotifier.logout()` 后状态变成 unauthenticated，守卫会自动回到登录页；页面不手工写 `context.go()`。

## 8. 深链和登录回跳

假设未登录用户从订单通知打开：

```text
/orders/100?tab=history
```

执行过程：

```text
/orders/100?tab=history
  -> /session-restoring?returnTo=...
  -> /login?returnTo=...
  -> 用户登录成功、authProvider 更新
  -> /orders/100?tab=history
```

登录按钮只调用 `LoginNotifier.login(account, password)`。Notifier 校验表单后调用 `SignIn` 抽象；默认
`SignInUseCase` 负责请求 LoginRepository、把 token/user 组成完整会话，再调用 `SessionActivator`。
`AuthNotifier` 是该端口的默认实现，负责写入 SessionStore 和更新 authProvider。

因此 `LoginPage` 不读取登录响应，`LoginNotifier` 也不直接依赖 AuthNotifier。无论最终回到订单页还是默认
首页，页面层和页面状态层都不需要知道具体会话存储与路由编排细节。

公开页面也会被保留，但恢复后不会强制登录。`returnTo` 只接受以 `/` 开头的 App 内部 URI，以下地址会被拒绝：

```text
https://evil.example
//evil.example
/login
/session-restoring
```

拒绝外部地址是为了避免攻击者利用登录成功回跳把用户带到仿冒网站。

`authenticatedHome` 自动受保护；其他页面使用 `protectedPaths` 或 `protectedPrefixes` 声明。

## 9. Warmup 为什么还要分两个时机

Bootstrap 和登录路由都完成后，仍有一些“不应阻塞页面”的全局任务：

| 阶段 | 任务示例 |
| --- | --- |
| `afterFirstFrame` | 崩溃监控初始化 |
| `afterSessionReady` | 远程配置、更新检查、统计 SDK |

阶段内任务并行且只执行一次。SQLite、地图和支付仍然由对应 Provider 第一次使用时初始化，不应塞进 Warmup。

## 10. 接入真实项目后怎样删除 Starter

创建项目路由文件：

```dart
AppRouteBundle createProjectRouteBundle() {
  return AppRouteBundle(
    authenticatedHome: '/dashboard',
    protectedPrefixes: const ['/dashboard', '/orders'],
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
    ],
  );
}
```

修改 `main.dart`：

```dart
import 'app/bootstrap/run_application.dart';
import 'project_routes.dart';

Future<void> main() {
  return runApplication(createProjectRouteBundle());
}
```

最后删除：

```text
lib/app/starter/
test/app/starter/
```

通用 AppRouter、AuthRouteGuard、RoutePaths、全局 ARB 和认证模块没有 Starter 引用，不需要继续修改。
