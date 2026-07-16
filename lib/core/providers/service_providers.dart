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
import 'package:sqflite/sqflite.dart';

import '../app/app_info_service.dart';
import '../database/database_service.dart';
import '../database/app_database.dart';
import '../database/sqlite_database_service.dart';
import '../network/api_client.dart';
import '../network/api_service.dart';
import '../network/network_status_service.dart';
import '../network/response_adapter.dart';
import '../permission/permission_service.dart';
import '../storage/secure_storage_service.dart';

/// 后端协议适配器。不同项目只需 override 此 Provider。
final responseAdapterProvider = Provider<ResponseAdapter>(
  (ref) => const EnvelopeResponseAdapter(),
);

/// 网络客户端由 Riverpod 容器拥有，不依赖静态单例，测试和多环境可以替换。
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(responseAdapter: ref.watch(responseAdapterProvider));
  ref.onDispose(client.close);
  return client;
});

final apiServiceProvider = Provider<ApiService>(
  // watch 表示 ApiClient Provider 如果被测试 override，ApiService 也同步重建。
  (ref) => ref.watch(apiClientProvider),
);

/// SQLite 数据库的按需初始化 Provider。
///
/// FutureProvider 默认是惰性的：仅声明它不会打开数据库。第一次 CRUD 操作读取
/// `.future` 时才执行 AppDatabase.database、打开文件并运行迁移。初始化失败会
/// 保存在 AsyncValue 中；需要人工重试时可 `ref.invalidate(appDatabaseProvider)`。
final appDatabaseProvider = FutureProvider<Database>((ref) {
  return AppDatabase.database;
});

/// 数据库服务（在当前 ProviderContainer 内共享，创建时不打开数据库）。
///
/// Repository 依赖抽象接口 DatabaseService，而不是直接依赖 sqflite。
final databaseServiceProvider = Provider<DatabaseService>(
  // SqliteDatabaseService 只保存“如何获取数据库”的闭包。真正执行 query/insert
  // 时才读取 FutureProvider，所以登录页和不使用本地缓存的项目不会为 SQLite
  // 支付启动耗时。
  (ref) => SqliteDatabaseService(
    databaseProvider: () => ref.read(appDatabaseProvider.future),
  ),
);

/// 网络状态服务（在当前 ProviderContainer 内共享）。
///
/// 统一封装 connectivity_plus，业务代码不直接依赖三方库。
final networkStatusServiceProvider = Provider<NetworkStatusService>(
  (ref) => ConnectivityNetworkStatusService(),
);

/// 权限服务（在当前 ProviderContainer 内共享）。
///
/// 统一封装 permission_handler。
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionHandlerService(),
);

/// App 信息服务（在当前 ProviderContainer 内共享）。
///
/// 统一封装 package_info_plus。
final appInfoServiceProvider = Provider<AppInfoService>(
  (ref) => PackageInfoAppInfoService(),
);

/// 敏感数据存储。认证模块通过自己的 SessionStore 再封装会话语义。
final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => FlutterSecureStorageService(),
);
