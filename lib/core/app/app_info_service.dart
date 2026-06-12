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
  /// 获取 App 信息。
  Future<AppInfo> getAppInfo();
}

/// 基于 package_info_plus 的 App 信息实现。
class PackageInfoAppInfoService implements AppInfoService {
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
