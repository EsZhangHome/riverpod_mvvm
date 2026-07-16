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
  -> ready/degraded：创建 ProviderScope 和 MyApp
  -> failed：显示启动失败页
```

这里的 `LocalStorage` 是普通偏好存储，主要服务主题和旧数据迁移。登录 Token 使用的是后面的
`SecureSessionStore`，所以 Bootstrap 完成不代表用户已经登录。

Bootstrap 不处理数据库、首页接口、地图、支付和普通 SDK 预热。

## 4. MyApp 创建稳定路由器

`MyApp` 创建一次 GoRouter，并把入口路由包交给它。普通冷启动地址固定为：

```text
/session-restoring
```

如果 App 是由通知或平台深链打开，GoRouter 会保留平台提供的内部地址。认证守卫在读取会话期间把这个地址
保存为安全 `returnTo`，不会直接丢到首页。

## 5. AuthNotifier 恢复安全会话

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

## 6. 守卫怎样决定最终页面

普通启动没有 returnTo：

| 认证状态 | 最终页面 |
| --- | --- |
| restoring | `/session-restoring` |
| unauthenticated | `/login` |
| authenticated | `AppRouteBundle.authenticatedHome` |

因此底座直接进入 Starter 只表示安全存储里已有完整会话。Starter 页面提供退出按钮，调用
`AuthNotifier.logout()` 后状态变成 unauthenticated，守卫会自动回到登录页；页面不手工写 `context.go()`。

## 7. 深链和登录回跳

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

公开页面也会被保留，但恢复后不会强制登录。`returnTo` 只接受以 `/` 开头的 App 内部 URI，以下地址会被拒绝：

```text
https://evil.example
//evil.example
/login
/session-restoring
```

拒绝外部地址是为了避免攻击者利用登录成功回跳把用户带到仿冒网站。

`authenticatedHome` 自动受保护；其他页面使用 `protectedPaths` 或 `protectedPrefixes` 声明。

## 8. Warmup 为什么还要分两个时机

Bootstrap 和登录路由都完成后，仍有一些“不应阻塞页面”的全局任务：

| 阶段 | 任务示例 |
| --- | --- |
| `afterFirstFrame` | 崩溃监控初始化 |
| `afterSessionReady` | 远程配置、更新检查、统计 SDK |

阶段内任务并行且只执行一次。SQLite、地图和支付仍然由对应 Provider 第一次使用时初始化，不应塞进 Warmup。

## 9. 接入真实项目后怎样删除 Starter

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
