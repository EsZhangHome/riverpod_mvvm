# Riverpod MVVM 独立学习应用

这个目录是一个完整、可独立运行和测试的 Flutter App，专门用业务场景讲解 Riverpod 3 + MVVM。
它不是企业底座的一部分，而是企业底座的一个消费者。

## 1. 为什么采用独立应用

依赖方向只有一条：

```text
riverpod_mvvm_demo
  -> path dependency: ../..
  -> riverpod_mvvm 企业底座
```

根项目没有 `riverpod_mvvm_demo` 依赖，也不 import 本目录中的任何文件，因此：

- 正式 App 不会编译案例页面、路由或文案。
- 本应用新增三方包时，不会污染企业底座的 `pubspec.yaml`。
- 本应用拥有自己的 Android、iOS、配置、测试和 IDE 启动项。
- 不需要学习代码时，删除整个 `examples/demo_app` 即可，根项目零修改。

如果反过来让企业底座通过 path dependency 引入 Demo，即使 Dart 代码最终被 tree-shaking，
依赖解析和原生插件发现阶段仍然知道 Demo 包，不符合“纯底座”的目标。

## 2. 运行

从当前目录执行：

```bash
flutter pub get
flutter run --dart-define-from-file=config/development.json
```

默认开启本地 Mock，不需要后端。登录页不会把案例账号或密码写进源码，输入任意非空邮箱和密码即可进入。

VSCode 可以直接使用当前目录 `.vscode/launch.json` 中的 `Flutter - Riverpod Learning App`。

## 3. 目录

```text
examples/demo_app/
  pubspec.yaml                 # 单向 path 依赖企业底座
  config/development.json      # 只属于学习应用的 Mock 配置
  android/ ios/                # 独立运行宿主，删除本目录时一起删除
  docs/
    riverpod_learning_path.md  # 基础 -> 异步 -> 全局详细学习路径
  lib/
    main.dart                  # 学习应用入口，Release 模式拒绝运行
    demo_route_bundle.dart     # 与底座 AppRouteBundle 的唯一组合点
    localization/             # 所有案例文案
    navigation/               # 案例路径与 StatefulShellRoute 外壳
    features/
      home/                    # 同步状态、购物车和页面请求生命周期
      orders/                  # AsyncNotifier、分页、family、Stream
      mine/                    # App 级 Provider 与平台 Service
      learning/                # 基础 -> 异步 -> 全局学习中心
      profile/                 # ViewState 与 AsyncRequestHandler
  test/                        # 只测试当前学习应用的案例
```

所有案例层级信息都保存在当前项目中。企业底座 README 不维护这些路径，避免移动案例后两份文档失去同步。

## 4. 学习顺序

App 的三个 Tab 组成连续业务链，而不是互不相关的计数器：

```text
商品目录与购物车（同步状态）
  -> 创建和管理订单（异步状态）
  -> 登录、主题和设备服务（全局状态）
```

| 阶段 | 业务问题 | Riverpod API | 推荐入口 |
| --- | --- | --- | --- |
| 基础 | 搜索、分类、收藏、购物车、汇总 | `Provider`、`NotifierProvider`、派生状态、`family`、`watch/read/listen/select` | `lib/features/home` |
| 异步 | 初载、刷新、分页、创建、取消、详情、物流 | `AsyncNotifierProvider`、`AsyncValue`、`FutureProvider.family`、`StreamProvider.family`、`refresh/invalidate` | `lib/features/orders` |
| 全局 | 登录态、主题、App 信息、网络状态 | App 级 Provider、Service 注入、跨页面共享、override | `lib/features/mine`、底座 `features/auth` |
| 生命周期 | 页面离开时停止网络与回写 | `autoDispose`、`ref.onDispose`、`ref.mounted`、`CancelToken` | `lib/features/home/view_model/home_view_model.dart` |

更细的逐步阅读说明见 [Riverpod 实战学习路径](docs/riverpod_learning_path.md)。

## 5. 每个案例仍遵循 MVVM

```text
View
  -> ViewModel（Notifier / AsyncNotifier）
  -> Repository
  -> 本地 Mock 或企业底座 Core Service
```

- Model：不可变业务数据，不读取 Provider。
- Repository：隐藏本地、Mock、HTTP 或 Stream 数据来源。
- ViewModel：拥有业务 State、命令、并发控制和生命周期。
- View：使用 `watch/select` 渲染，使用 `read` 发命令，使用 `listen` 执行 SnackBar 等副作用。

案例不会为了展示某个 Riverpod API 而破坏业务职责。能用派生 Provider 计算的数据不重复存进 State；
页面销毁时，CancelToken 停止 IO，`ref.mounted` 阻止异步结果写回已释放 Notifier。

## 6. 重点代码

### 基础：商品与购物车

推荐阅读：

1. `lib/features/home/model/product.dart`
2. `lib/features/home/repository/product_repository.dart`
3. `lib/features/home/view_model/catalog_view_model.dart`
4. `lib/features/home/view/home_page.dart`
5. `lib/features/home/view/cart_page.dart`
6. `test/features/home/catalog_providers_test.dart`

重点观察 `watch/read/listen/select` 的职责差异、`.family` 如何隔离单商品数量，以及购物车为何在 Tab
切换和 push 详情页后仍然保留。

### 异步：订单

推荐阅读：

1. `lib/features/orders/model/order.dart`
2. `lib/features/orders/repository/order_repository.dart`
3. `lib/features/orders/view_model/order_view_model.dart`
4. `lib/features/orders/view/orders_page.dart`
5. `test/features/orders/order_providers_test.dart`

重点观察首屏 `AsyncValue`、局部命令 loading、分页合并、乐观取消与失败回滚、详情 TTL、并发竞态、
`FutureProvider.family` 和 `StreamProvider.family` 的释放。

### 全局：我的

推荐阅读：

1. `lib/features/mine/view_model/mine_view_model.dart`
2. `lib/features/mine/view/mine_page.dart`
3. `test/features/mine/mine_service_providers_test.dart`
4. 企业底座 `lib/features/auth`
5. 企业底座 `lib/shared/theme/theme_provider.dart`

重点观察 App 级登录态、主题持久化、平台 Service Provider、测试 override 和路由刷新桥接。

## 7. 测试与代码生成

```bash
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
```

测试通过 `ProviderContainer.overrides` 替换 Repository 或平台 Service，不访问真实网络。
`HomeBanner` 的 `*.g.dart` 属于当前应用，由当前应用自己的 build_runner 负责生成。

## 8. 删除

回到仓库根目录直接删除：

```bash
rm -rf examples/demo_app
```

不需要再修改根项目的：

- `pubspec.yaml`
- `lib/main.dart`
- AppRouter 或 RoutePaths
- `.vscode/launch.json`
- 根项目测试或 CI
- README 的架构和业务模块说明

删除后剩余内容就是可直接启动新项目开发的企业级底座。
