// lib/core/config/env_config.dart
//
// 作用：统一管理 App 的环境配置，支持通过 --dart-define 在编译时切换环境。
//
// 设计要点：
// 1. 所有配置值都是 static const，编译时常量，零运行时开销
// 2. 使用 String.fromEnvironment / int.fromEnvironment / bool.fromEnvironment 读取编译参数
// 3. 每个配置项都有 defaultValue，默认值指向生产环境
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
// # 生产环境（使用默认值）
// flutter run
// ```
//
// 扩展方式：
// 新增配置项时，只需要添加一个 static const 字段，
// 使用 Xxx.fromEnvironment 读取，并提供合理的 defaultValue。

import 'package:flutter/foundation.dart';

/// 环境配置统一入口。
///
/// 所有与环境相关的配置都集中在这里，不在代码中硬编码。
/// 启动 App 时可以通过 --dart-define 覆盖默认值。
class EnvConfig {
  const EnvConfig._();

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
  /// 只对超时和连接异常生效，不会重试业务错误（4xx/5xx）和请求取消。
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
  /// - false（默认）：Repository 调用真实后端接口
  ///
  /// 通过 --dart-define 切换：
  /// ```bash
  /// flutter run --dart-define=ENV_ENABLE_MOCK=true
  /// ```
  static const bool enableMock = bool.fromEnvironment(
    'ENV_ENABLE_MOCK',
    defaultValue: true, // 当前项目处于演示阶段，默认使用 Mock 数据
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
}
