// lib/core/config/env_config.dart
//
// 作用：统一管理 App 的环境配置，支持通过 --dart-define 在编译时切换环境。
//
// 设计要点：
// 1. dart-define 原始值使用 static const 固化进构建产物；current getter 再把它们
//    组合成便于校验和测试的 EnvironmentConfig
// 2. 使用 String.fromEnvironment / int.fromEnvironment / bool.fromEnvironment 读取编译参数
// 3. 每个配置项都有开发安全默认值；生产构建必须显式提供并通过校验
// 4. 通过 --dart-define 可以在不修改代码的情况下切换开发/测试/生产环境
//
// 使用方式：
// ```bash
// # 开发环境
// flutter run --dart-define=ENV_API_BASE_URL=https://dev-api.example.com
//
// # 测试环境
// flutter run --dart-define=ENV_API_BASE_URL=https://test-api.example.com
//
// # 生产构建（先从 production.example.json 复制并替换真实地址）
// flutter build apk --release --dart-define-from-file=config/local.json
// ```
//
// 扩展方式：
// 新增配置项时，只需要添加一个 static const 字段，
// 使用 Xxx.fromEnvironment 读取，并提供合理的 defaultValue。

import 'package:flutter/foundation.dart';

import 'app_environment.dart';

/// 环境配置统一入口。
///
/// 所有与环境相关的配置都集中在这里，不在代码中硬编码。
/// 启动 App 时可以通过 --dart-define 覆盖默认值。
class EnvConfig {
  const EnvConfig._();

  // ==================== 应用环境 ====================

  /// `ENV_NAME`：环境名称，支持 development/testing/staging/production 及常用别名。
  /// 默认 development；解析和安全规则见 [environment]、EnvironmentValidator。
  static const String environmentName = String.fromEnvironment(
    'ENV_NAME',
    defaultValue: 'development',
  );

  /// `ENV_APP_NAME`：展示在系统任务、启动页和 MaterialApp 中的应用名称。
  /// 它不是 pubspec 的 package name，也不会自动修改 Android/iOS 包标识。
  static const String appName = String.fromEnvironment(
    'ENV_APP_NAME',
    defaultValue: 'Riverpod MVVM',
  );

  // ==================== 隐私政策配置 ====================

  /// 当前要求用户同意的隐私政策版本。
  ///
  /// 这里必须是稳定业务版本，例如 `2026.07.01`，不能使用构建时间或随机值。App
  /// 会把“用户已同意的版本”保存到普通偏好；当本值升级后，旧版本不再匹配，
  /// `PrivacyConsentHost` 会在当前页面上展示全局升级弹窗。首次没有记录时先进入
  /// 登录页并自动提示；拒绝后未勾选点击登录仍会再次展示。
  static const String privacyPolicyVersion = String.fromEnvironment(
    'ENV_PRIVACY_POLICY_VERSION',
    defaultValue: 'starter-1',
  );

  /// 当前完整隐私政策文档版本。
  ///
  /// 它可以随错别字、排版或联系方式修订而变化，但不会单独触发重新同意。只有上面的
  /// ENV_PRIVACY_POLICY_VERSION（授权版本）变化才会进入政策升级状态。
  static const String privacyPolicyDocumentVersion = String.fromEnvironment(
    'ENV_PRIVACY_POLICY_DOCUMENT_VERSION',
    defaultValue: 'starter-document-1',
  );

  /// 用户可以阅读的完整隐私政策地址。
  ///
  /// 底座页面会展示该地址，真实项目必须替换为可公开访问的 HTTPS 页面。它不是
  /// 接口 Base URL，也不要在 query 中拼接用户 id、设备标识或登录态。
  static const String privacyPolicyUrl = String.fromEnvironment(
    'ENV_PRIVACY_POLICY_URL',
    defaultValue: 'https://privacy.example.com/policy',
  );

  /// 当前用户协议正文版本，用于在同意记录中准确追溯用户看到的文本。
  static const String userAgreementDocumentVersion = String.fromEnvironment(
    'ENV_USER_AGREEMENT_DOCUMENT_VERSION',
    defaultValue: 'starter-user-agreement-1',
  );

  /// 用户可以阅读的完整用户协议地址。
  static const String userAgreementUrl = String.fromEnvironment(
    'ENV_USER_AGREEMENT_URL',
    defaultValue: 'https://privacy.example.com/user-agreement',
  );

  // ==================== 网络配置 ====================

  /// 接口基础地址。
  ///
  /// 示例：
  /// ```bash
  /// flutter run --dart-define=ENV_API_BASE_URL=https://dev-api.example.com
  /// ```
  static const String apiBaseUrl = String.fromEnvironment(
    'ENV_API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );

  /// Dio 建立 TCP 连接的最大等待时间（秒）。
  ///
  /// 超过这个时间还没建立连接，Dio 会抛出 connectionTimeout 错误。
  static const int connectTimeout = int.fromEnvironment(
    'ENV_CONNECT_TIMEOUT',
    defaultValue: 15,
  );

  /// Dio 接收服务器响应数据的最大等待时间（秒）。
  ///
  /// 超过这个时间服务器还没返回完整响应，Dio 会抛出 receiveTimeout 错误。
  static const int receiveTimeout = int.fromEnvironment(
    'ENV_RECEIVE_TIMEOUT',
    defaultValue: 15,
  );

  /// Dio 发送请求体的最大等待时间（秒）。
  ///
  /// 超过这个时间请求体还没发送完，Dio 会抛出 sendTimeout 错误。
  static const int sendTimeout = int.fromEnvironment(
    'ENV_SEND_TIMEOUT',
    defaultValue: 15,
  );

  /// 网络请求重试次数。
  ///
  /// 它只是 RetryInterceptor 的次数上限：默认只有 GET/HEAD 的临时连接或超时
  /// 异常会重试；写请求还必须通过 RequestContext 明确声明幂等。
  /// 不会重试 HTTP 4xx/5xx、证书错误和请求取消。
  /// 每次重试之间有退避等待（第 1 次 1 秒，第 2 次 2 秒）。
  static const int retryCount = int.fromEnvironment(
    'ENV_RETRY_COUNT',
    defaultValue: 2,
  );

  // ==================== Charles 抓包配置 ====================

  /// 是否启用 Charles 代理抓包。
  ///
  /// 默认关闭，正常开发、测试、生产包都不会走代理。
  /// 只有需要抓接口包时，才通过 --dart-define 临时打开：
  /// ```bash
  /// flutter run \
  ///   --dart-define=ENV_ENABLE_CHARLES_PROXY=true \
  ///   --dart-define=ENV_CHARLES_PROXY_HOST=192.168.1.10 \
  ///   --dart-define=ENV_CHARLES_PROXY_PORT=8888
  /// ```
  ///
  /// 注意：
  /// - iOS 模拟器通常可以用 127.0.0.1 或电脑局域网 IP
  /// - Android 模拟器访问电脑本机一般用 10.0.2.2
  /// - 真机需要填写电脑在同一 Wi-Fi 下的局域网 IP
  static const bool enableCharlesProxy = bool.fromEnvironment(
    'ENV_ENABLE_CHARLES_PROXY',
    defaultValue: false,
  );

  /// Charles 代理地址。
  ///
  /// 这里给一个本机默认值，实际使用时建议通过 --dart-define 覆盖成当前电脑 IP。
  static const String charlesProxyHost = String.fromEnvironment(
    'ENV_CHARLES_PROXY_HOST',
    defaultValue: '127.0.0.1',
  );

  /// Charles 代理端口。
  ///
  /// Charles 默认 HTTP Proxy 端口是 8888，如果你在 Charles 里改过端口，
  /// 这里也要保持一致。
  static const int charlesProxyPort = int.fromEnvironment(
    'ENV_CHARLES_PROXY_PORT',
    defaultValue: 8888,
  );

  /// 是否允许 Charles 场景下跳过 HTTPS 证书校验。
  ///
  /// 默认关闭。推荐优先在手机或模拟器里安装并信任 Charles 根证书。
  /// 只有临时调试证书问题时才打开，release 包不要开启。
  static const bool allowCharlesBadCertificate = bool.fromEnvironment(
    'ENV_ALLOW_CHARLES_BAD_CERTIFICATE',
    defaultValue: false,
  );

  // ==================== 业务配置 ====================

  /// 业务成功码。
  ///
  /// 国内常见接口一般 code == 0 表示成功，如果你的后端用其他值（如 200），
  /// 可以通过 --dart-define=ENV_API_SUCCESS_CODE=200 修改。
  static const int apiSuccessCode = int.fromEnvironment(
    'ENV_API_SUCCESS_CODE',
    defaultValue: 0,
  );

  /// 是否使用 HTTP 状态码判断成功。
  ///
  /// - true：使用 HTTP 状态码判断，200-299 表示成功（RESTful 风格）
  /// - false（默认）：使用 apiSuccessCode 判断成功（业务码风格）
  static const bool useHttpStatus = bool.fromEnvironment(
    'ENV_USE_HTTP_STATUS',
    defaultValue: false,
  );

  // ==================== Mock 配置 ====================

  /// 是否启用 Mock 数据模式。
  ///
  /// - true：Repository 返回模拟数据，不发起真实网络请求（开发/演示阶段使用）
  /// - false：Repository 调用真实后端接口
  ///
  /// 通过 --dart-define 切换：
  /// ```bash
  /// flutter run --dart-define=ENV_ENABLE_MOCK=true
  /// ```
  static const bool enableMock = bool.fromEnvironment(
    'ENV_ENABLE_MOCK',
    defaultValue: true, // 教学仓库默认可离线运行；正式配置会强制关闭
  );

  // ==================== 调试配置 ====================

  /// 是否 debug 模式。
  ///
  /// 默认跟随 Flutter 的 kDebugMode（debug 编译为 true，release 编译为 false）。
  /// 可以通过 --dart-define 强制覆盖。
  static const bool isDebug = bool.fromEnvironment(
    'ENV_IS_DEBUG',
    defaultValue: kDebugMode,
  );

  /// 把 [environmentName] 解析成强类型枚举；名称非法时抛 ConfigurationException。
  static AppEnvironment get environment =>
      AppEnvironment.parse(environmentName);

  /// 汇总所有 dart-define 原始值，生成一次安全校验使用的不可变快照。
  static EnvironmentConfig get current => EnvironmentConfig(
    environment: environment,
    appName: appName,
    apiBaseUrl: apiBaseUrl,
    privacyPolicyVersion: privacyPolicyVersion,
    privacyPolicyDocumentVersion: privacyPolicyDocumentVersion,
    privacyPolicyUrl: privacyPolicyUrl,
    userAgreementDocumentVersion: userAgreementDocumentVersion,
    userAgreementUrl: userAgreementUrl,
    enableMock: enableMock,
    enableDebugLogs: isDebug,
    enableCharlesProxy: enableCharlesProxy,
    allowBadCertificate: allowCharlesBadCertificate,
  );

  /// 启动时执行安全校验；正式包配置不安全时抛 ConfigurationException。
  ///
  /// [releaseMode] 默认使用 Flutter 的 kReleaseMode。参数开放出来仅用于测试不同
  /// 构建模式；生产代码不应手工传 false 绕过 release 安全校验。
  /// development 非 release 构建也会检查基本地址和应用名，只是不强制关闭调试能力。
  static void ensureValid({bool releaseMode = kReleaseMode}) {
    final issues = EnvironmentValidator.validate(
      current,
      releaseMode: releaseMode,
    );
    if (issues.isNotEmpty) throw ConfigurationException(issues);
  }
}
