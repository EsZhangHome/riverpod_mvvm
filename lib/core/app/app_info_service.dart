// lib/core/app/app_info_service.dart
//
// 作用：统一获取 App 基础信息。
//
// 常见使用场景：
// - 关于页面展示版本号
// - 日志里记录当前 App 版本
// - 后续崩溃上报时附带版本信息

import 'package:package_info_plus/package_info_plus.dart';

/// App 基础信息。
class AppInfo {
  /// 创建一份不可变的应用信息快照。
  ///
  /// - [appName]：安装包向系统声明的展示名称，例如“订单助手”；
  /// - [packageName]：Android applicationId 或 iOS bundle identifier；
  /// - [version]：面向用户的版本号，例如 `1.2.0`；
  /// - [buildNumber]：同一版本下递增的构建号，例如 `37`。
  const AppInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  /// App 名称。
  final String appName;

  /// 包名 / bundle identifier。
  final String packageName;

  /// 版本号，例如 1.0.0。
  final String version;

  /// 构建号，例如 1。
  final String buildNumber;

  /// 常见展示格式，例如 1.0.0+1。
  String get displayVersion => '$version+$buildNumber';
}

/// App 信息服务抽象。
abstract class AppInfoService {
  /// 获取当前安装包信息。
  ///
  /// 首次调用可能通过平台通道读取 Android/iOS 元数据，因此返回 Future。实现可以
  /// 缓存结果；应用版本在一次进程运行期间不会变化，业务无需频繁强制刷新。
  /// 平台插件异常会继续抛给调用方，由 FutureProvider/Repository 决定页面状态。
  Future<AppInfo> getAppInfo();
}

/// 基于 package_info_plus 的 App 信息实现。
class PackageInfoAppInfoService implements AppInfoService {
  /// 进程内缓存。null 表示还没有成功读取；失败结果不会缓存，下一次可重新尝试。
  AppInfo? _cachedAppInfo;

  @override
  Future<AppInfo> getAppInfo() async {
    final cachedAppInfo = _cachedAppInfo;
    if (cachedAppInfo != null) {
      return cachedAppInfo;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final appInfo = AppInfo(
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
    _cachedAppInfo = appInfo;
    return appInfo;
  }
}
