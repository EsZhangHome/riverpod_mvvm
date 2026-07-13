// lib/features/mine/view_model/mine_view_model.dart
//
// 学习路径第三站：App 级状态与服务 Provider。
// authProvider/themeProvider 是跨路由共享的全局 Notifier；本文件再把底层
// AppInfoService、NetworkStatusService 转换为 View 可直接消费的 AsyncValue。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_info_service.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/network/network_status_service.dart';
import '../../../core/providers/services.dart';
import '../../../global/auth_provider.dart';

/// FutureProvider 适合只有“读取”行为、无需公开命令方法的异步数据。
/// AppInfoService 自带缓存；Provider 只负责把 Future 转成 AsyncValue。
final appInfoProvider = FutureProvider.autoDispose<AppInfo>((ref) {
  return ref.watch(appInfoServiceProvider).getAppInfo();
});

/// StreamProvider 先发出当前网络状态，再持续转发插件的变化事件。
/// 页面离开或非当前根 Tab 的订阅被暂停并释放后，Riverpod 会自动取消 Stream。
final networkStatusProvider = StreamProvider.autoDispose<NetworkStatus>((
  ref,
) async* {
  final service = ref.watch(networkStatusServiceProvider);
  yield await service.getCurrentStatus();
  yield* service.watchStatus();
});

/// 派生全局登录态。这里只读取 View 真正需要的字段，页面不必依赖完整 AuthState。
final sessionDescriptionProvider = Provider<String>((ref) {
  final user = ref.watch(authProvider.select((state) => state.currentUser));
  return user == null
      ? AppStrings.noLoggedUser
      : '${user.name} · ${user.email}';
});
