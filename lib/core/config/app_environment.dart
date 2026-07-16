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
  const EnvironmentConfig({
    required this.environment,
    required this.appName,
    required this.apiBaseUrl,
    required this.enableMock,
    required this.enableDebugLogs,
    required this.enableCharlesProxy,
    required this.allowBadCertificate,
  });

  /// 当前开发、测试、预发或生产环境。
  final AppEnvironment environment;

  /// 展示给用户的应用名称，不是 Dart package name。
  final String appName;

  /// 所有 API 请求共用的绝对基础地址。
  final String apiBaseUrl;

  /// 是否使用本地 Mock 数据；正式包必须关闭。
  final bool enableMock;

  /// 是否输出调试日志；正式包必须关闭，避免泄露诊断信息。
  final bool enableDebugLogs;

  /// 是否把请求发送到本地 Charles 代理。
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
  static List<String> validate(
    EnvironmentConfig config, {
    required bool releaseMode,
  }) {
    final issues = <String>[];
    // 防止有人用 development 环境名构建 release 来绕开生产限制。
    final strict = releaseMode || config.isProduction;
    final uri = Uri.tryParse(config.apiBaseUrl);

    if (config.appName.trim().isEmpty) issues.add('ENV_APP_NAME 不能为空');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      issues.add('ENV_API_BASE_URL 不是有效的绝对地址');
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
      if (config.enableMock) issues.add('正式环境必须关闭 Mock');
      if (config.enableDebugLogs) issues.add('正式环境必须关闭调试日志');
      if (config.enableCharlesProxy) issues.add('正式环境必须关闭抓包代理');
      if (config.allowBadCertificate) issues.add('正式环境禁止跳过证书校验');
    }
    return List.unmodifiable(issues);
  }
}
