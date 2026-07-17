# 第三方依赖与许可证说明

> 最近核对：2026-07-17。数据来自当前 `pubspec.yaml`、`pubspec.lock` 和各 Package 自带的 LICENSE。

这份清单帮助项目接入方进行依赖审查和发布准备，不构成法律意见，也不替代法务、应用市场或客户合同要求。
它只说明第三方组件的许可；仓库根目录当前没有声明项目自身的 LICENSE。对外开源、交付源码或分发衍生产品
前，项目所有者必须补充适合自己的开源许可证或专有版权声明。

## 运行时直接依赖

| 组件 | 当前解析版本 | 主要用途 | 许可证 |
| --- | --- | --- | --- |
| Flutter / `flutter_localizations` | 3.44.x | UI、平台运行时、国际化 | BSD-3-Clause |
| `cupertino_icons` | 1.0.9 | Cupertino 图标 | MIT |
| `flutter_riverpod` | 3.3.2 | 状态管理与依赖注入 | MIT |
| `dio` | 5.9.2 | HTTP 客户端 | MIT |
| `go_router` | 17.3.0 | 声明式路由 | BSD-3-Clause |
| `shared_preferences` | 2.5.5 | 普通偏好存储 | BSD-3-Clause |
| `flutter_secure_storage` | 10.3.1 | Keychain/Keystore 安全存储 | BSD-3-Clause |
| `intl` | 0.20.2 | 日期、数字与国际化基础能力 | BSD-3-Clause |
| `sqflite` | 2.4.3 | SQLite 数据库 | BSD-2-Clause |
| `path` | 1.9.1 | 跨平台路径处理 | BSD-3-Clause |
| `json_annotation` | 4.12.0 | JSON 生成注解 | BSD-3-Clause |
| `cached_network_image` | 3.4.1 | 网络图片缓存与展示 | MIT |
| `connectivity_plus` | 7.1.1 | 系统网络连接状态 | BSD-3-Clause |
| `permission_handler` | 12.0.3 | Android/iOS 权限适配 | MIT |
| `package_info_plus` | 10.2.1 | App 版本与包信息 | BSD-3-Clause |
| `url_launcher` | 6.3.2 | 打开 HTTPS 政策链接 | BSD-3-Clause |

## 仅开发和构建使用

这些依赖不会以业务 API 的形式进入运行时，但构建工具、生成代码和测试仍受各自许可证约束。

| 组件 | 当前解析版本 | 主要用途 | 许可证 |
| --- | --- | --- | --- |
| Flutter Test / Integration Test | 3.44.x | 单元、Widget、集成测试 | BSD-3-Clause |
| `flutter_lints` | 6.0.0 | 静态规则 | BSD-3-Clause |
| `build_runner` | 2.15.0 | 代码生成调度 | BSD-3-Clause |
| `json_serializable` | 6.14.0 | JSON 序列化生成 | BSD-3-Clause |
| `sqflite_common_ffi` | 2.4.2 | 桌面测试 SQLite | BSD-2-Clause |
| `flutter_native_splash` | 2.4.8 | 原生启动图生成 | MIT |
| `flutter_launcher_icons` | 0.14.4 | App 图标生成 | MIT |

## 传递依赖和原生组件

上表只列直接依赖。每次 `flutter pub get` 还会解析 Riverpod、Dio、各平台插件等传递依赖；Android Gradle、
Kotlin/AndroidX、iOS CocoaPods 和 Flutter Engine 也可能进入最终产物。完整版本来源以 `pubspec.lock`、
`android`/`ios` 锁定文件和实际 Release 构建为准。

发布前建议：

1. 执行 `flutter pub deps --json` 保存本次构建的依赖树。
2. 检查每个直接和传递 Package 的 LICENSE，确认版权声明、NOTICE 和二进制分发要求。
3. 在 App 的“关于/开源许可”页面展示 Flutter 自动收集的 Package Licenses，或按公司流程生成 NOTICE。
4. 检查原生 SDK 是否包含额外隐私政策、商业条款、出口限制或商标要求。
5. 将依赖清单、源码 Commit、构建号和发布产物哈希一起归档，便于审计和漏洞响应。

## 新增或升级依赖时

- 先说明为什么现有底座能力不能满足，不要只因为使用方便就增加依赖。
- 核对维护状态、最新发布时间、已知漏洞、支持平台、包体影响和初始化时机。
- 更新本文件中的用途、解析版本和许可证。
- Dependabot PR 也必须经过 CI、许可证检查和 major 版本迁移评估。
- GPL、AGPL、SSPL、商业 SDK 或来源不清的二进制依赖必须先由项目负责人和法务确认，不能直接合并。
