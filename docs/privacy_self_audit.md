# 开发阶段怎样自己检查隐私合规

这套工具解决的是一个很具体的问题：代码评审时只看 `pubspec.yaml`，很难知道插件最终增加了
什么权限；只搜索 `ANDROID_ID`，又看不到三方插件的原生代码；等应用市场驳回后再排查，成本太高。

因此项目把检查拆成三层：

```text
源码与依赖静态检查（每天、CI 自动执行）
  -> Release APK 检查（提审前执行）
  -> 真机动态调用观察（重要版本人工执行）
```

这些检查是研发门禁，不是法律意见，也不能替代应用市场检测。工具“通过”表示没有命中当前规则，
不表示所有页面、所有 SDK 和所有地区的合规要求都已经自动证明。

## 1. 日常开发检查

先执行 `flutter pub get`，让 Flutter 生成最终原生插件解析文件，再运行：

```bash
dart run tool/privacy/privacy_audit.dart --mode development
```

结果会同时生成：

- `build/reports/privacy-audit.md`：开发和测试直接阅读。
- `build/reports/privacy-audit.json`：CI 或其他平台继续处理。

`build/` 已被 Git 忽略，报告不会进入正式包，也不会污染仓库。默认发现 `blocker` 时进程返回
`1`，CI 会失败；只有 `review` 或 `info` 时继续通过。

三种等级的含义：

| 等级 | 含义 | 应该怎样处理 |
| --- | --- | --- |
| `blocker` | 未登记原生插件、未登记/禁止权限、Android ID/IMEI 等明确风险 | 合并前处理，不要直接放行 |
| `review` | 静态代码不能单独判断是否合法，或真实项目资料尚未补齐 | 由开发、测试和法务结合业务确认 |
| `info` | 已登记调用、模板域名或建议显式配置的项目 | 用来理解最终包，不阻断日常开发 |

如需临时查看所有结果但不阻断，可使用 `--fail-on none`。这个参数只适合排查，不能用来修改 CI
逃避问题。

## 2. 配置文件为什么是审计核心

所有项目声明保存在 `compliance/privacy_audit.json`，主要包括：

- `allowedPermissions`：允许进入 Android 包的权限及用途。
- `forbiddenPermissions`：底座默认禁止的高敏或过度权限。
- `allowedExportedComponents`：允许被外部调用的 Android 组件、用途和必须具备的保护权限。
- `allowedDomains`：运行期可能请求的域名、用途、是否只是模板占位。
- `sensitiveApis`：Android ID、IMEI、应用列表、剪贴板等源码、DEX 引用和二进制扫描规则。
- `nativePlugins`：最终会注册到 Android 的插件、已复核版本、用途和数据类型。
- `approvedFindings`：已经逐行确认的特殊调用及理由。
- `releaseRequirements`：隐私政策环境键、同意门禁和账号注销的代码标记。

白名单不是“看到报错就加进去”。正确流程是：

1. 确认能力是否为核心业务所必需，不需要就删除。
2. 查看插件原生源码、Manifest、官方隐私说明和初始化时机。
3. 确认用户是否已被告知、是否在合适时机同意、能否撤回。
4. 把用途和数据写入配置，同时更新 App 内隐私政策、应用市场数据安全表单和测试用例。
5. 插件升级后重新审查。工具会把“实际版本与登记版本不同”标记为 `review`。

`.flutter-plugins-dependencies` 是 `flutter pub get` 生成的本地文件，不能手改，也不用提交。工具读取
它的原因是：一个 Dart 依赖可能再间接引入 Android 插件，仅阅读直接依赖并不完整。

## 3. 新项目接入时必须填写什么

底座故意保留了模板域名和空的隐私政策信息。开发模式只提示，`release` 模式会阻断，避免客户把
示例配置直接发布。

至少完成下面几项：

1. 把 `config/*.json` 和 `EnvConfig` 默认值替换为真实 HTTPS 域名。
2. 同步更新 `allowedDomains`，记录每个域名的所有者和用途。
3. 在环境配置填写 `ENV_PRIVACY_POLICY_URL`、`ENV_USER_AGREEMENT_URL`、授权版本
   `ENV_PRIVACY_POLICY_VERSION` 和两份正文版本 `ENV_PRIVACY_POLICY_DOCUMENT_VERSION`、
   `ENV_USER_AGREEMENT_DOCUMENT_VERSION`；审计器会直接读取本次环境文件，
   不需要再复制一份 URL。
4. 底座已经提供隐私版本状态机、首次登录前弹窗和全局升级弹窗；真实项目需要替换完整政策内容，并确认所有
   敏感 SDK 都只在当前版本同意后初始化。
5. 有账号体系时实现服务端账号注销，把真实方法名加入 `accountDeletionMarkers`；没有账号体系时
   由项目合规记录说明不适用，并删除该检查标记。
6. 对照真实业务重新整理权限和原生插件清单，不要保留已删除 Demo 或功能的声明。

隐私门禁必须控制的是“可能采集或上传个人信息的初始化”，不是阻止所有启动任务。环境校验、本地
普通配置等不采集信息的任务可以先执行；统计、广告、推送、设备风控等 SDK 应在符合项目政策的
同意状态之后初始化。

## 4. 提审前检查最终 Release APK

源码 Manifest 只能看到项目主动声明的内容，最终包还会合并三方 AAR/插件权限。因此要检查真实
待发布产物：

```bash
flutter build apk --release \
  --dart-define-from-file=config/local.json

dart run tool/privacy/privacy_audit.dart \
  --mode release \
  --environment-file config/local.json \
  --apk build/app/outputs/flutter-apk/app-release.apk
```

APK 模式额外执行：

- 使用 Android SDK `apkanalyzer` 读取最终合并权限和 Manifest。
- 使用 `apkanalyzer dex packages` 判断 API 所属类，例如区分电话标识读取与同名的
  `MotionEvent.getDeviceId`，减少只搜方法名产生的误报。
- 读取 `classes*.dex` 与 `lib/*.so` 的字符串，补充检查 Android ID、OAID 等唯一信号。
- 继续执行源码、SDK、域名和发布资料检查。

`--environment-file` 必须与上一步 `flutter build` 使用同一个文件。release 审计只把这个文件当成本次
发布配置，不会因为仓库中保留的 development/testing/production.example 模板地址而误报；如果漏传或
文件不存在，则直接阻断。

运行环境需要 Android SDK Command-line Tools 和 `unzip`。缺少 `apkanalyzer` 时，release 模式会
直接阻断，因为此时无法证明最终合并权限是什么。

二进制出现字符串只说明代码被打包，不代表一定运行；没有出现也不代表可以跳过动态测试。混淆、反射、
动态下发和 native 实现都可能让单一静态方式漏报。

## 5. 真机观察敏感 API 到底何时调用

项目提供 `tool/privacy/android_privacy_hooks.js`。它通过 Frida 观察 Android ID、电话标识、设备序列号、
Wi-Fi 标识、剪贴板、应用列表和广告 ID 等入口。

脚本只输出 API 名、非敏感参数说明和调用栈，不输出 API 返回值，避免审计工具自己制造一份个人信息日志。

每条 `PRIVACY_AUDIT` 日志还包含：

- `unknown_early`：Application Context 尚不可用，不能证明已同意，按同意前处理；
- `pre_consent`：没有同意记录，或者记录版本已经过期，标记为 `block_candidate`；
- `post_consent`：已同意版本与当前版本一致，标记为 `review_candidate`，仍需核对必要性和政策范围。

运行前确认脚本顶部 `PRIVACY_CONSENT_CONFIG.currentPolicyVersion` 与本次构建的
`ENV_PRIVACY_POLICY_VERSION` 一致。脚本会在每次敏感调用时重新读取
`FlutterSharedPreferences` 中的 `privacy_consent_record_v1` JSON，并兼容旧版单字符串 key，所以同一次进程里
点击同意后，后续日志会自动切换到 `post_consent`。

准备专用测试设备并按 Frida 官方方式启动匹配版本的 `frida-server` 后执行：

```bash
frida -U -f <你的 applicationId> \
  -l tool/privacy/android_privacy_hooks.js --no-pause \
  | tee build/reports/privacy-dynamic.log
```

测试时至少覆盖：

1. 首次安装后进入登录页，确认未选中的协议复选框和首次弹窗自动显示；同意前停留一段时间，确认没有敏感调用。
2. 拒绝后弹窗关闭、复选框保持未选中且本次运行不再自动重复；未勾选点击登录必须再次弹出且不发送请求。
3. 同意后应选中复选框；账号密码完整时续接登录，不完整时只选中且不显示输入 Toast。拒绝后冷启动仍保持
   未同意，下一次未勾选登录仍必须拦截。
4. 保留旧同意版本升级到新政策构建，在首页和深层详情页确认全局升级弹窗都不能绕过。
5. 升级同意后确认仍停留在原页面；升级拒绝后确认会话清除并回到登录页，下次冷启动再次提示。
6. 登录、首页、核心业务页面和权限申请。
7. 切到后台再恢复、断网重连、普通退出登录。
8. 推送、统计、地图、客服、分享、广告等真实项目集成的 SDK 场景。

旧版本不等于当前版本时，动态脚本仍会把调用归类为 `pre_consent`。底座会暂停尚未运行的 AppWarmup，
但已经由原生层自动启动或在旧进程中运行的 SDK 不一定支持通用反初始化，因此政策升级拒绝路径还要验证
具体 SDK 的“停止采集/清除用户标识”接口，不能只检查页面是否回到了登录页。

看到 `PRIVACY_AUDIT` 日志后，根据调用栈定位到 App 或具体 SDK。尤其关注“用户同意前调用”和“页面
未使用相关功能却调用”。Frida 适合公司授权的测试设备和自有 App，不要用于未授权应用。

快速筛选同意前调用：

```bash
rg '"phase":"(unknown_early|pre_consent|unknown_error)"' \
  build/reports/privacy-dynamic.log
```

## 6. CI 门禁

根项目 CI 在 `flutter pub get` 后自动执行 development 审计。这样新增插件、权限或敏感 API 时，
Pull Request 会立即失败，并在控制台给出报告路径。

日常 CI 不自动构建 Release APK，原因是底座仓库没有客户的正式签名和真实生产配置。真实项目应该在
发布流水线完成 Release 产物后，再执行 `--mode release --apk ...`，并把 Markdown/JSON 报告作为构建
产物留档；同时必须传入构建时使用的 `--environment-file`。

## 7. 目前不能自动判断的内容

下面事项仍需要人工或专项平台：

- 隐私政策文字是否准确覆盖真实数据流和第三方主体。
- 服务端收到数据后怎样存储、共享、删除和跨境传输。
- SDK 是否通过反射、动态代码或加密 native 逻辑采集信息。
- 权限弹窗前的业务说明是否清楚，拒绝后是否仍能使用非相关功能。
- 注销是否真的删除服务端数据，而不只是清除本地登录状态。
- 各应用市场、行业和地区在当前版本的额外规则。

因此最稳妥的发布流程仍然是：机器静态门禁 + Release 产物扫描 + 真机动态测试 + 隐私政策/数据流人工
复核。四者解决的问题不同，不能互相替代。
