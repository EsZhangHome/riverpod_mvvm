// lib/core/providers/services.dart
//
// 作用：所有底层服务的 Riverpod Provider 声明，替代 get_it 的 registerLazySingleton。
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
  (ref) => ref.watch(apiClientProvider),
);

/// 数据库服务（全局单例）。
///
/// Repository 依赖抽象接口 DatabaseService，而不是直接依赖 sqflite。
final databaseServiceProvider = Provider<DatabaseService>(
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
