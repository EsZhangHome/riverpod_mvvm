// lib/core/config/app_environment.dart
//
// 把“从 dart-define 读取值”和“判断配置是否安全”拆成两个文件：
// EnvConfig 负责读取编译期常量，本文件负责纯 Dart 模型与校验规则。
// 这样测试可以直接构造 EnvironmentConfig，不需要真的重新编译四种环境。

/// 应用支持的运行环境。
///
/// 业务代码依赖枚举而不是散落的 `prod`、`uat` 字符串，拼写错误会更早暴露，
/// switch 也能由编译器检查是否覆盖了所有环境。
enum AppEnvironment {
  development,
  testing,
  staging,
  production;

  /// 把 dart-define 或配置文件中的字符串转换为稳定枚举。
  ///
  /// [value] 会先去除首尾空格并转成小写；支持 dev/test/uat/prod 等常用别名。
  /// 无法识别时抛出 ConfigurationException，而不是静默回退 development，避免
  /// 因拼写错误使用了错误服务器。
  static AppEnvironment parse(String value) {
    // 兼容团队常用缩写，但最终统一成枚举，避免业务到处比较字符串。
    return switch (value.trim().toLowerCase()) {
      'dev' || 'development' => AppEnvironment.development,
      'test' || 'testing' => AppEnvironment.testing,
      'staging' || 'stage' || 'uat' => AppEnvironment.staging,
      'prod' || 'production' => AppEnvironment.production,
      _ => throw ConfigurationException(['不支持的运行环境：$value']),
    };
  }
}

/// 从多个编译期常量收敛出的不可变配置快照。
///
/// 为什么不用 Map：字段能被 IDE 自动补全，改名有编译器检查，也不会把 bool
/// 写成字符串。为什么不在这里保存 secret：dart-define 会进入编译产物，不安全。
class EnvironmentConfig {
  /// 创建一份用于校验的完整环境快照。
  ///
  /// 该构造函数主要由 EnvConfig.current 和单元测试使用。它不主动校验参数；安全
  /// 规则统一放在 EnvironmentValidator.validate，避免“对象无法构造”和“问题无法
  /// 一次收集完整”之间冲突。
  const EnvironmentConfig({
    required this.environment,
    required this.appName,
    required this.apiBaseUrl,
    required this.privacyPolicyVersion,
    required this.privacyPolicyDocumentVersion,
    required this.privacyPolicyUrl,
    required this.userAgreementDocumentVersion,
    required this.userAgreementUrl,
    required this.enableMock,
    required this.enableDebugLogs,
    required this.enableCharlesProxy,
    required this.allowBadCertificate,
  });

  /// 当前开发、测试、预发或生产环境，决定是否主动启用生产级严格校验。
  final AppEnvironment environment;

  /// 展示给用户的应用名称，不是 Dart package name。
  final String appName;

  /// 所有 API 请求共用的绝对基础地址，例如 `https://api.example.cn`。
  /// 必须包含 scheme 和 host；末尾是否带 `/` 需与接口 path 约定保持一致。
  final String apiBaseUrl;

  /// 用户本次需要同意的隐私政策业务版本；版本变化会触发重新确认。
  final String privacyPolicyVersion;

  /// 当前公开政策正文版本；普通文字修订只更新它，不强制用户重复确认。
  final String privacyPolicyDocumentVersion;

  /// 完整隐私政策的公开绝对地址；正式环境必须使用 HTTPS 且不能是模板域名。
  final String privacyPolicyUrl;

  /// 当前公开用户协议正文版本，用于同意记录追溯。
  final String userAgreementDocumentVersion;

  /// 完整用户协议的公开绝对地址；正式环境必须使用 HTTPS 且不能是模板域名。
  final String userAgreementUrl;

  /// 是否允许 Repository 选择本地 Mock 数据；正式或 release 包必须关闭。
  final bool enableMock;

  /// 是否允许默认 DebugLogSink 输出调试日志；正式包必须关闭。
  /// 自定义远程 LogSink 仍应自行实现脱敏、等级和采样策略。
  final bool enableDebugLogs;

  /// 是否把 ApiClient 请求发送到本地 Charles 代理。
  final bool enableCharlesProxy;

  /// 是否允许代理的非可信证书。仅限本地联调，正式包绝不能开启。
  final bool allowBadCertificate;

  /// 是否显式选择 production 环境。
  /// release 构建是否启用严格规则还取决于校验器收到的 `releaseMode`，不由本
  /// getter 单独判断。
  bool get isProduction => environment == AppEnvironment.production;
}

/// 配置错误属于启动阻断问题，不能带着不安全参数继续运行正式包。
class ConfigurationException implements Exception {
  /// 创建包含全部配置问题的异常。
  ///
  /// [issues] 应是面向开发者的稳定问题列表，不应包含 secret。EnvConfig 会在列表
  /// 非空时抛出本异常，Bootstrap 将其视为 critical 并阻断启动。
  const ConfigurationException(this.issues);

  /// 一次保存全部问题，让开发者改完一批后再重启，而不是逐个试错。
  final List<String> issues;

  @override
  String toString() => 'ConfigurationException(${issues.join(', ')})';
}

/// 环境配置的纯校验器。
///
/// 类没有实例状态，所以使用 `abstract final` 作为静态命名空间：不能被 new，
/// 也不能被继承。纯函数设计让单元测试可以直接覆盖所有环境组合。
abstract final class EnvironmentValidator {
  /// 返回全部问题而不是遇到第一个就抛出，开发者一次即可修完所有错误。
  /// 真正是否抛异常由 EnvConfig.ensureValid/AppBootstrap 决定。
  ///
  /// - [config]：需要校验的不可变配置快照；
  /// - [releaseMode]：当前是否为 Flutter release 构建。即使 config.environment
  ///   写成 development，只要该值为 true 仍会启用 HTTPS、关闭 Mock 等严格规则，
  ///   防止通过错误环境名绕过发布保护。
  ///
  /// 返回不可变问题列表；空列表表示通过。本方法不抛已知校验问题，方便测试和
  /// 启动页一次展示全部原因。
  static List<String> validate(
    EnvironmentConfig config, {
    required bool releaseMode,
  }) {
    final issues = <String>[];
    // 防止有人用 development 环境名构建 release 来绕开生产限制。
    final strict = releaseMode || config.isProduction;
    final uri = Uri.tryParse(config.apiBaseUrl);
    final privacyUri = Uri.tryParse(config.privacyPolicyUrl);
    final userAgreementUri = Uri.tryParse(config.userAgreementUrl);

    if (config.appName.trim().isEmpty) issues.add('ENV_APP_NAME 不能为空');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      issues.add('ENV_API_BASE_URL 不是有效的绝对地址');
    }
    if (config.privacyPolicyVersion.trim().isEmpty) {
      issues.add('ENV_PRIVACY_POLICY_VERSION 不能为空');
    }
    if (config.privacyPolicyDocumentVersion.trim().isEmpty) {
      issues.add('ENV_PRIVACY_POLICY_DOCUMENT_VERSION 不能为空');
    }
    if (privacyUri == null ||
        !privacyUri.hasScheme ||
        privacyUri.host.isEmpty) {
      issues.add('ENV_PRIVACY_POLICY_URL 不是有效的绝对地址');
    }
    if (config.userAgreementDocumentVersion.trim().isEmpty) {
      issues.add('ENV_USER_AGREEMENT_DOCUMENT_VERSION 不能为空');
    }
    if (userAgreementUri == null ||
        !userAgreementUri.hasScheme ||
        userAgreementUri.host.isEmpty) {
      issues.add('ENV_USER_AGREEMENT_URL 不是有效的绝对地址');
    }

    if (strict) {
      // Release 中的以下开关可能泄露数据、绕过证书或把假数据发给用户，
      // 因此不是“警告”，而是必须阻断启动的配置错误。
      if (uri?.scheme != 'https') issues.add('正式环境 API 必须使用 HTTPS');
      if (uri?.host.endsWith('example.com') ?? false) {
        issues.add('正式环境不能使用示例 API 地址');
      }
      if (uri?.host.endsWith('.invalid') ?? false) {
        issues.add('正式环境不能使用占位 API 地址');
      }
      if (privacyUri?.scheme != 'https') {
        issues.add('正式环境隐私政策必须使用 HTTPS');
      }
      if (privacyUri?.host.endsWith('example.com') ?? false) {
        issues.add('正式环境不能使用示例隐私政策地址');
      }
      if (privacyUri?.host.endsWith('.invalid') ?? false) {
        issues.add('正式环境不能使用占位隐私政策地址');
      }
      if (userAgreementUri?.scheme != 'https') {
        issues.add('正式环境用户协议必须使用 HTTPS');
      }
      if (userAgreementUri?.host.endsWith('example.com') ?? false) {
        issues.add('正式环境不能使用示例用户协议地址');
      }
      if (userAgreementUri?.host.endsWith('.invalid') ?? false) {
        issues.add('正式环境不能使用占位用户协议地址');
      }
      if (config.privacyPolicyVersion == 'starter-1' ||
          config.privacyPolicyVersion.startsWith('replace-with-')) {
        issues.add('正式环境不能使用模板隐私授权版本');
      }
      if (config.privacyPolicyDocumentVersion == 'starter-document-1' ||
          config.privacyPolicyDocumentVersion.startsWith('replace-with-')) {
        issues.add('正式环境不能使用模板隐私政策文档版本');
      }
      if (config.userAgreementDocumentVersion == 'starter-user-agreement-1' ||
          config.userAgreementDocumentVersion.startsWith('replace-with-')) {
        issues.add('正式环境不能使用模板用户协议文档版本');
      }
      if (config.enableMock) issues.add('正式环境必须关闭 Mock');
      if (config.enableDebugLogs) issues.add('正式环境必须关闭调试日志');
      if (config.enableCharlesProxy) issues.add('正式环境必须关闭抓包代理');
      if (config.allowBadCertificate) issues.add('正式环境禁止跳过证书校验');
    }
    return List.unmodifiable(issues);
  }
}
