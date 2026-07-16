// lib/features/mine/view_model/mine_view_model.dart
//
// 学习路径第三站：App 级状态与服务 Provider。
// authProvider/themeProvider 是跨路由共享的全局 Notifier；本文件再把底层
// AppInfoService 转换为 View 可直接消费的 AsyncValue；网络状态由底座公共的
// networkStatusProvider 提供，Demo 不重复声明第二份平台监听。
//
// 依赖方向始终是 Service Provider -> 页面 Provider -> MinePage，
// View 不导入 package_info_plus 或 connectivity_plus。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:riverpod_mvvm/core/app/app_info_service.dart';
import '../../../localization/demo_strings.dart';
import 'package:riverpod_mvvm/core/providers/service_providers.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

/// FutureProvider 适合只有“读取”行为、无需公开命令方法的异步数据。
/// AppInfoService 自带缓存；Provider 只负责把 Future 转成 AsyncValue。
final appInfoProvider = FutureProvider.autoDispose<AppInfo>((ref) {
  // watch 允许测试 override Service 后自动使用 Fake 实现。
  return ref.watch(appInfoServiceProvider).getAppInfo();
});

/// 派生全局登录态。这里只读取 View 真正需要的字段，页面不必依赖完整 AuthState。
final sessionDescriptionProvider = Provider<String>((ref) {
  // 只选择 currentUser，token 刷新不会无意义地重新计算文案。
  final user = ref.watch(authProvider.select((state) => state.currentUser));
  return user == null
      ? DemoStrings.noLoggedUser
      : '${user.name} · ${user.email}';
});
