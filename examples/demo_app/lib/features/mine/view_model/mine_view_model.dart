// lib/features/mine/view_model/mine_view_model.dart
//
// 学习路径第三站：App 级状态与服务 Provider。
// authProvider/themeProvider 是跨路由共享的全局 Notifier；本文件再把底层
// AppInfoService、NetworkStatusService 转换为 View 可直接消费的 AsyncValue。
//
// 依赖方向始终是 Service Provider -> 页面 Provider -> MinePage，
// View 不导入 package_info_plus 或 connectivity_plus。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:riverpod_mvvm/core/app/app_info_service.dart';
import '../../../localization/demo_strings.dart';
import 'package:riverpod_mvvm/core/network/network_status_service.dart';
import 'package:riverpod_mvvm/core/providers/service_providers.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

/// FutureProvider 适合只有“读取”行为、无需公开命令方法的异步数据。
/// AppInfoService 自带缓存；Provider 只负责把 Future 转成 AsyncValue。
final appInfoProvider = FutureProvider.autoDispose<AppInfo>((ref) {
  // watch 允许测试 override Service 后自动使用 Fake 实现。
  return ref.watch(appInfoServiceProvider).getAppInfo();
});

/// StreamProvider 先发出当前网络状态，再持续转发插件的变化事件。
/// Riverpod 3 会暂停不可见 TickerMode 下的 Widget 订阅；当 autoDispose Provider
/// 最终没有活动监听且被销毁时，Riverpod 才会取消底层 Stream 订阅。是否立即销毁
/// 仍取决于是否还有其他监听者或 keepAlive，不能简单等同于每次切换 Tab 都重建。
final networkStatusProvider = StreamProvider.autoDispose<NetworkStatus>((
  ref,
) async* {
  // 步骤 1：先读取一次当前状态，页面无需等待插件产生下一次变化事件。
  final service = ref.watch(networkStatusServiceProvider);
  yield await service.getCurrentStatus();
  // 步骤 2：持续转发后续状态；Provider dispose 时 Riverpod 取消订阅。
  yield* service.watchStatus();
});

/// 派生全局登录态。这里只读取 View 真正需要的字段，页面不必依赖完整 AuthState。
final sessionDescriptionProvider = Provider<String>((ref) {
  // 只选择 currentUser，token 刷新不会无意义地重新计算文案。
  final user = ref.watch(authProvider.select((state) => state.currentUser));
  return user == null
      ? DemoStrings.noLoggedUser
      : '${user.name} · ${user.email}';
});
