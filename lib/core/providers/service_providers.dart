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
import '../network/network_quality_monitor.dart';
import '../network/response_adapter.dart';
import '../permission/permission_service.dart';
import '../storage/secure_storage_service.dart';

/// 后端外层响应协议适配器。
///
/// 默认解析 `{code, message, data}`，也兼容普通 REST body。若公司的字段名、成功码
/// 或 data 包装完全不同，应在项目最外层 ProviderScope override 本 Provider，而不是
/// 修改每个 Repository。ApiClient 通过 watch 订阅它，override 后会使用新适配器。
final responseAdapterProvider = Provider<ResponseAdapter>(
  (ref) => const EnvelopeResponseAdapter(),
);

/// 持有 Dio、拦截器和连接配置的网络客户端。
///
/// 生命周期属于当前 ProviderContainer：首次被读取时创建，容器销毁时通过
/// ref.onDispose 关闭 Dio。测试可 override 成注入 MockAdapter 的 ApiClient。
/// 业务 Repository 不应直接读取本 Provider，应依赖下面的 apiServiceProvider。
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    responseAdapter: ref.watch(responseAdapterProvider),
    networkQualityMonitor: ref.watch(networkQualityMonitorProvider),
  );
  ref.onDispose(client.close);
  return client;
});

/// Repository 面向的网络抽象入口。
///
/// 返回类型故意声明为 ApiService，隐藏 ApiClient 的大部分实现细节。这里用 watch
/// 而不是 read，使测试 override apiClientProvider 后，本 Provider 能同步重建。
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
/// 测试可 override 为 FakeDatabaseService；业务无需启动平台数据库插件。
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
/// Provider 只创建服务对象，真正的平台监听在 watchStatus 被消费时才开始。
final networkStatusServiceProvider = Provider<NetworkStatusService>(
  (ref) => ConnectivityNetworkStatusService(),
);

/// App 级连接状态流：先查询当前网络，再持续监听平台连接类型变化。
///
/// 它和 [networkStatusServiceProvider] 的区别：Service 是可替换的平台能力，当前
/// Provider 才是 View/ViewModel 直接消费的 Riverpod 状态。这里不使用 autoDispose，
/// 因为 MyApp 会在整个应用生命周期监听它；Provider 本身仍是惰性的，没人读取时不会
/// 创建 connectivity_plus 监听，ProviderContainer 销毁时 Stream 也会自动取消。
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) async* {
  final service = ref.watch(networkStatusServiceProvider);
  var previous = await service.getCurrentStatus();
  yield previous;
  // 插件在部分系统上会把“当前值”作为监听首值再次发送，也可能连续发送相同类型。
  // 手工与 getCurrentStatus 的首值比较，才能过滤查询结果与监听流之间的重复事件；
  // 只对 watchStatus 调用 distinct 无法跨越两个 Stream 片段去重。
  await for (final next in service.watchStatus()) {
    if (next == previous) continue;
    previous = next;
    yield next;
  }
});

/// 真实接口网络质量监控器。
///
/// ApiClient 和 App 根监听读取的是同一个实例：前者写入请求样本，后者只监听事件。
/// 具体项目可 override 本 Provider 调整慢请求阈值，而不修改 ApiClient。
final networkQualityMonitorProvider = Provider<NetworkQualityMonitor>((ref) {
  final monitor = NetworkQualityMonitor();
  ref.onDispose(monitor.dispose);
  return monitor;
});

/// 把纯 Dart Monitor 的广播流转换成 Riverpod AsyncValue。
///
/// 这里只发送质量跨级事件，不持续保存每次请求耗时，避免网络请求导致 Widget 高频
/// 重建。详细耗时仍由 AppPerformance 负责记录和上报。
final networkQualityEventsProvider = StreamProvider<NetworkQualityEvent>((ref) {
  return ref.watch(networkQualityMonitorProvider).events;
});

/// 权限服务（在当前 ProviderContainer 内共享）。
///
/// 统一封装 permission_handler。
/// 测试 override 后可以验证授权/拒绝分支而不弹系统权限框。
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionHandlerService(),
);

/// App 信息服务（在当前 ProviderContainer 内共享）。
///
/// 统一封装 package_info_plus。
/// 实现内部缓存首次平台读取结果；页面通常再用 FutureProvider 暴露 AsyncValue。
final appInfoServiceProvider = Provider<AppInfoService>(
  (ref) => PackageInfoAppInfoService(),
);

/// 敏感键值存储（在当前 ProviderContainer 内共享）。
///
/// 这里仅提供 read/write/delete 能力，不知道 token、用户或会话版本。认证模块应再
/// 通过 SessionStore 封装完整会话语义；普通业务不要直接散落安全存储 key。
final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => FlutterSecureStorageService(),
);
