// lib/features/mine/view/mine_page.dart
//
// 第三站强调“作用域”：
// - authProvider/themeProvider 是 App 级状态，切换 Tab 或路由后仍然存在；
// - appInfo 是页面级异步状态，networkStatus 是底座全 App 共享的连接状态；
// - View 通过 select 降低对大型全局 State 的依赖。
//
// 页面执行顺序：
// 1. watch 登录摘要、主题切片、App 信息和网络流；
// 2. AsyncValue.when 分别渲染 Future/Stream 的 loading/error/data；
// 3. read 主题 Notifier 或 invalidate App 信息执行用户命令；
// 4. 右上角 push 独立学习中心，不把教学内容塞进业务 Tab；
// 5. 退出登录清理 App 会话，再由 GoRouter 回到登录页。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../localization/demo_strings.dart';
import 'package:riverpod_mvvm/core/network/network_status_service.dart';
import 'package:riverpod_mvvm/core/providers/service_providers.dart';
import 'package:riverpod_mvvm/shared/navigation/route_paths.dart';
import '../../../navigation/demo_route_paths.dart';
import 'package:riverpod_mvvm/shared/theme/app_spacing.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/shared/theme/theme_provider.dart';
import '../view_model/mine_view_model.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 派生 Provider 已把 UserModel 转成页面需要的一行摘要。
    final sessionDescription = ref.watch(sessionDescriptionProvider);
    // select 只订阅 themeMode，不因 ThemeState 中其他字段变化重建本页。
    final themeMode = ref.watch(
      themeProvider.select((state) => state.themeMode),
    );
    final appInfo = ref.watch(appInfoProvider);
    final network = ref.watch(networkStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(DemoStrings.mineTitle),
        actions: [
          IconButton(
            tooltip: DemoStrings.openRiverpodLearning,
            // push 保留“我的”页面，学习中心返回后仍处在同一 Tab。
            onPressed: () => context.push(DemoRoutePaths.riverpodLearning),
            icon: const Icon(Icons.school_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _ScopeTitle(
            index: 1,
            title: DemoStrings.appNotifierTitle,
            description: DemoStrings.appNotifierDescription,
          ),
          _InfoCard(icon: Icons.account_circle, text: sessionDescription),
          const SizedBox(height: AppSpacing.lg),
          const _ScopeTitle(
            index: 2,
            title: DemoStrings.selectGlobalStateTitle,
            description: DemoStrings.selectGlobalStateDescription,
          ),
          Card(
            child: SwitchListTile(
              value: themeMode == ThemeMode.dark,
              title: const Text(DemoStrings.globalDarkTheme),
              subtitle: const Text(DemoStrings.globalDarkThemeDescription),
              onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ScopeTitle(
            index: 3,
            title: DemoStrings.futureServiceTitle,
            description: DemoStrings.futureServiceDescription,
          ),
          appInfo.when(
            // FutureProvider 自动把 Future 转换为 AsyncValue 三态。
            loading: () => const _InfoCard(
              icon: Icons.info_outline,
              text: DemoStrings.readingAppInfo,
            ),
            error: (error, _) => const _InfoCard(
              icon: Icons.error_outline,
              text: DemoStrings.appInfoReadFailed,
            ),
            data: (info) => _InfoCard(
              icon: Icons.apps,
              text:
                  '${info.appName}\n${info.packageName}\n${info.displayVersion}',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ScopeTitle(
            index: 4,
            title: DemoStrings.streamServiceTitle,
            description: DemoStrings.streamServiceDescription,
          ),
          network.when(
            // Stream 每发出一个 NetworkStatus，data 分支都会刷新。
            loading: () => const _InfoCard(
              icon: Icons.network_check,
              text: DemoStrings.checkingNetwork,
            ),
            error: (error, _) => const _InfoCard(
              icon: Icons.signal_wifi_bad,
              text: DemoStrings.networkListenFailed,
            ),
            data: (status) => _InfoCard(
              icon: status.isConnected ? Icons.wifi : Icons.wifi_off,
              text: _networkLabel(status.type),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            // 当前页面正在 watch，所以 invalidate 后 FutureProvider 会在后续帧重建；
            // View 仍然不直接调用底层 Service。
            onPressed: () => ref.invalidate(appInfoProvider),
            icon: const Icon(Icons.refresh),
            label: const Text(DemoStrings.reloadAppInfo),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text(DemoStrings.logout),
          ),
        ],
      ),
    );
  }

  String _networkLabel(NetworkConnectionType type) {
    return DemoStrings.currentConnection(_networkTypeLabel(type));
  }

  String _networkTypeLabel(NetworkConnectionType type) => switch (type) {
    NetworkConnectionType.wifi => DemoStrings.connectionWifi,
    NetworkConnectionType.mobile => DemoStrings.connectionMobile,
    NetworkConnectionType.ethernet => DemoStrings.connectionEthernet,
    NetworkConnectionType.bluetooth => DemoStrings.connectionBluetooth,
    NetworkConnectionType.satellite => DemoStrings.connectionSatellite,
    NetworkConnectionType.vpn => DemoStrings.connectionVpn,
    NetworkConnectionType.other => DemoStrings.connectionOther,
    NetworkConnectionType.none => DemoStrings.connectionNone,
  };

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    // 先等待 token 和用户资料清理完成，避免下一页面读到半退出状态。
    await ref.read(authProvider.notifier).logout();
    // await 后检查 BuildContext 生命周期。
    if (context.mounted) context.go(RoutePaths.login);
  }
}

class _ScopeTitle extends StatelessWidget {
  const _ScopeTitle({
    required this.index,
    required this.title,
    required this.description,
  });
  final int index;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('$index')),
      title: Text(title),
      subtitle: Text(description),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
