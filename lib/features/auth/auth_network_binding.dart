// 认证模块与网络基础设施的组合点。
//
// AuthNotifier 是 ViewModel，只管理登录会话；ApiClient 是基础设施，只管理 HTTP。
// 二者不应该互相 import。这个 Provider 位于模块组合层，负责把双方的稳定能力接在
// 一起，因此以后替换认证页面或网络实现时，不会把改动扩散到状态机内部。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import 'view_model/auth_view_model.dart';

/// 把最新 Token、401 退出和刷新命令绑定到同一个 ApiClient。
///
/// Provider 本身没有业务 State，返回 void。App 根节点 watch 一次即可；ApiClient
/// 通过闭包在每次请求时读取最新状态，不会缓存旧 Token，也不会重建拦截器链。
final authNetworkBindingProvider = Provider<void>((ref) {
  final client = ref.watch(apiClientProvider);

  client.setTokenProvider(() => ref.read(authProvider).token);
  client.setUnauthorizedCallback(
    () => ref.read(authProvider.notifier).logout(),
  );
  client.setTokenRefreshCallback(
    () => ref.read(authProvider.notifier).refreshAccessToken(),
  );

  // UnauthorizedGuard 在一次 401 风暴中只允许退出一次。用户重新登录或恢复出
  // 有效会话后必须 reset，下一次真正过期时才能再次处理 401。
  ref.listen(authProvider, (previous, next) {
    if (next.isLoggedIn && previous?.isLoggedIn != true) {
      client.resetUnauthorizedGuard();
    }
  });
});
