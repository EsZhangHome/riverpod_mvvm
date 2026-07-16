// lib/core/providers/service_providers.dart
//
// 作用：集中声明底层服务的 Riverpod Provider，作为基础设施依赖注入入口。
//
// 注册的服务：
// - ApiService：网络请求统一入口
// - DatabaseService：本地数据库抽象
// - NetworkStatusService：网络连接状态
// - PermissionService：权限管理
// - AppInfoService：App 信息
//
// 使用方式：
// ```dart
// // 在 Notifier 的 build() 或方法中通过 ref 获取
// final apiService = ref.read(apiServiceProvider);
// ```
//
// 阅读顺序：
// 1. ApiClient 是真正持有 Dio、拦截器和 token 回调的底层对象；
// 2. ApiService 是 Repository 面向的抽象请求入口；
// 3. 其他平台插件先封装成 Service 接口，再通过 Provider 注入；
// 4. 测试通过 override 替换某个 Service，业务层不需要启动真实插件。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_info_service.dart';
import '../database/database_service.dart';
import '../database/sqlite_database_service.dart';
import '../network/api_client.dart';
import '../network/api_service.dart';
import '../network/network_status_service.dart';
import '../permission/permission_service.dart';

/// 网络服务（全局单例）。
///
/// 所有 Repository 共享同一个 ApiClient.instance，共享拦截器、token 配置。
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

final apiServiceProvider = Provider<ApiService>(
  // watch 表示 ApiClient Provider 如果被测试 override，ApiService 也同步重建。
  (ref) => ref.watch(apiClientProvider),
);

/// 数据库服务（全局单例）。
///
/// Repository 依赖抽象接口 DatabaseService，而不是直接依赖 sqflite。
final databaseServiceProvider = Provider<DatabaseService>(
  // 对外暴露接口类型，隐藏 sqflite 的具体实现。
  (ref) => SqliteDatabaseService(),
);

/// 网络状态服务（全局单例）。
///
/// 统一封装 connectivity_plus，业务代码不直接依赖三方库。
final networkStatusServiceProvider = Provider<NetworkStatusService>(
  (ref) => ConnectivityNetworkStatusService(),
);

/// 权限服务（全局单例）。
///
/// 统一封装 permission_handler。
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionHandlerService(),
);

/// App 信息服务（全局单例）。
///
/// 统一封装 package_info_plus。
final appInfoServiceProvider = Provider<AppInfoService>(
  (ref) => PackageInfoAppInfoService(),
);
