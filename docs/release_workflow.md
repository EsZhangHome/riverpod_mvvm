# 手动 Release Workflow 使用说明

`.github/workflows/release.yml` 是企业项目接入发布平台前的安全示例。它只响应 GitHub Actions 的手动
`workflow_dispatch`，不会因为 push、合并或创建 Tag 自动发布。

## 默认行为

手动运行后，工作流会：

1. 检查输入 Tag 与 `pubspec.yaml` 版本一致。
2. 检查生产配置文件位于 `config/*.json`。
3. 执行国际化、格式、生成代码、静态分析、测试和覆盖率门禁。
4. 从 GitHub Secrets 生成临时 Android 签名文件。
5. 构建签名 APK 和 AAB。
6. 验证文件存在、大小合理且是有效 ZIP 容器。
7. 生成 SHA-256 校验文件并上传为 Actions Artifact。

`publish_github_release` 默认是 `false`。只有明确改为 `true`，并且构建使用的不是模板或 development 配置，
才会进入 `production` Environment 创建或更新 GitHub Release。

## 必需的 GitHub Secrets

在仓库 `Settings → Secrets and variables → Actions` 中配置：

| Secret | 说明 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Android upload keystore 的 Base64 内容 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 签名别名 |
| `ANDROID_KEY_PASSWORD` | 别名密码 |

在本地生成 Base64 时不要把结果写进仓库：

```bash
base64 < upload-keystore.jks | tr -d '\n'
```

工作流只在临时 Runner 中创建 `android/key.properties` 和 keystore；两者已被 `.gitignore` 排除。

## production Environment

建议在 GitHub `Settings → Environments → production` 中至少配置：

- Required reviewers：发布前必须由负责人批准。
- Deployment branches/tags：只允许受保护分支或正式 Tag。
- 按组织需要配置等待时间、审计和环境级 Secrets。

Environment 没有保护规则时，勾选发布后会直接执行，因此真实项目不能省略这一步。

## 配置文件要求

模板默认使用 `config/production.example.json`，它只能验证 Release 构建流程，不能发布。真实项目应复制为
例如 `config/production.json`，替换 API、隐私政策和版本配置后提交安全的非机密项。

不要把密码、Token 或私钥写入 `dart-define` JSON：`dart-define` 会进入构建产物，不是 Secret 存储。真正的
运行时机密应由后端交换、系统安全存储或组织的配置服务提供。

## 新项目必须调整

- Flutter 版本应与项目实际基线和 CI 保持一致。
- Android applicationId、签名证书、版本策略和产物命名。
- GitHub Release 是否符合公司的应用市场、MDM、Firebase App Distribution 或其他分发流程。
- Release Notes 来源、制品保留时间和审批人。
- 如果不在 GitHub 发布，删除 `publish-github-release` Job，替换为公司的发布适配器。

示例没有自动发布 iOS。iOS 证书、Provisioning Profile、App Store Connect API Key、ExportOptions 和 Team ID
都属于具体组织配置，不应该在通用底座里提供看似可用、实际不安全的默认值。接入时应另建 macOS Job，并用
受保护 Environment 管理签名和上传权限。
