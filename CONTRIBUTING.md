# 贡献指南

感谢参与 Riverpod MVVM 企业 Flutter 底座。这个仓库的目标不是收集尽可能多的组件，而是保持一套能直接
启动真实项目、职责清楚、可以按需删除 Demo 和 Starter 的最小生产基础。

## 开始之前

1. 先阅读 [README](README.md) 的启动链路和目录边界。
2. 接入真实项目时阅读 [企业项目启动指南](docs/enterprise_starter.md)。
3. 安全问题遵循 [SECURITY.md](SECURITY.md)，不要在公开 Issue 中提交漏洞或敏感日志。
4. 新增或升级依赖时核对 [第三方依赖与许可证](docs/third_party_licenses.md)。

## 本地环境

项目基线是 Flutter `3.44.x stable`、Dart `>=3.12.0 <4.0.0`、Riverpod `3.3.2`。

```bash
flutter pub get
cp config/development.json config/local.json
flutter run --dart-define-from-file=config/local.json
```

`config/local.json`、签名文件、Token 和生产环境参数不能提交。

## 架构边界

业务代码遵守下面的依赖方向：

```text
View → ViewModel/Notifier → UseCase → Repository → Service
```

- View 只展示状态和发送命令，不直接访问 Dio、数据库或安全存储。
- ViewModel 不保存 `BuildContext`，也不拼装具体网络请求。
- 只有跨 Repository 或全局状态编排时才增加 UseCase；简单转发不需要多一层。
- Repository 依赖 Service 抽象，不弹 Toast、不导航、不返回页面 State。
- 平台插件集中在允许的 Adapter 中，通过 Provider 注入，Feature 不直接 import 三方基础设施库。
- 新能力必须有真实消费者；不要为了“以后可能用”增加万能 Base 类或未使用工具。

架构边界由 `test/architecture/dependency_rules_test.dart` 自动检查，不要通过增加白名单绕过合理分层。

## Demo、Starter 与正式底座

- `examples/demo_app` 是独立学习应用，不参与根 App 构建。
- `lib/app/starter` 是根 App 可删除的占位路由和本地 Mock 组合。
- 通用能力不能反向依赖 Demo 或 Starter。
- 修改删除路径时要同步验证 README 中的删除步骤仍然成立。

## 文案和生成代码

用户可见文案写入 `lib/l10n/app_zh.arb` 和 `app_en.arb`，不要在 Widget 中硬编码中文。

```bash
flutter gen-l10n
dart run tool/check_l10n.dart
```

`app_localizations*.dart`、`*.g.dart` 等文件由工具生成，不要手工修改。修改 Model 或 ARB 后重新生成并提交
生成结果，确保 `git diff` 只包含预期变化。

## 提交前验证

```bash
flutter gen-l10n
dart run tool/check_l10n.dart
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart --minimum 70
```

涉及路由、登录、会话、安全存储或 SQLite 时，还应在 Android/iOS 模拟器或真机运行相关集成测试。CI 命令
不能代替需要系统权限、后台切换、弱网和 Release 模式的人工验证。

## 分支、Commit 和 Pull Request

- 从最新 `main` 创建聚焦分支，例如 `feat/...`、`fix/...`、`refactor/...`、`docs/...`。
- Commit 推荐使用 Conventional Commits，例如 `feat: 增加订单筛选`、`fix: 修复会话恢复竞态`。
- 一个 PR 只解决一个明确问题，不混入无关格式化、依赖升级或重命名。
- 按 PR 模板写明测试、风险和回滚方式；UI 变更提供深色模式、窄屏或多语言截图。

## 依赖和发布

- Dependabot 每周检查 pub 与 GitHub Actions 更新；依赖升级必须通过完整 CI，major 版本单独评估迁移影响。
- 手动发布示例见 [Release Workflow 使用说明](docs/release_workflow.md)。默认工作流不会因为 push/tag 自动发包。
- 新项目复制底座后，要替换 CODEOWNERS、安全入口、应用标识、生产配置、签名和发布渠道。
