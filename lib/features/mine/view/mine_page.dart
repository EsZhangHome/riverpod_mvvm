// lib/features/mine/view/mine_page.dart
//
// 第三站强调“作用域”：
// - authProvider/themeProvider 是 App 级状态，切换 Tab 或路由后仍然存在；
// - appInfo/networkStatus 是页面消费的异步服务状态，离开后可自动释放；
// - View 通过 select 降低对大型全局 State 的依赖。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/network_status_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../global/auth_provider.dart';
import '../../../global/theme_provider.dart';
import '../view_model/mine_view_model.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionDescription = ref.watch(sessionDescriptionProvider);
    final themeMode = ref.watch(
      themeProvider.select((state) => state.themeMode),
    );
    final appInfo = ref.watch(appInfoProvider);
    final network = ref.watch(networkStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.mineTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.openRiverpodLearning,
            onPressed: () => context.push(RoutePaths.riverpodLearning),
            icon: const Icon(Icons.school_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _ScopeTitle(
            index: 1,
            title: AppStrings.appNotifierTitle,
            description: AppStrings.appNotifierDescription,
          ),
          _InfoCard(icon: Icons.account_circle, text: sessionDescription),
          const SizedBox(height: AppSpacing.lg),
          const _ScopeTitle(
            index: 2,
            title: AppStrings.selectGlobalStateTitle,
            description: AppStrings.selectGlobalStateDescription,
          ),
          Card(
            child: SwitchListTile(
              value: themeMode == ThemeMode.dark,
              title: const Text(AppStrings.globalDarkTheme),
              subtitle: const Text(AppStrings.globalDarkThemeDescription),
              onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ScopeTitle(
            index: 3,
            title: AppStrings.futureServiceTitle,
            description: AppStrings.futureServiceDescription,
          ),
          appInfo.when(
            loading: () => const _InfoCard(
              icon: Icons.info_outline,
              text: AppStrings.readingAppInfo,
            ),
            error: (error, _) => const _InfoCard(
              icon: Icons.error_outline,
              text: AppStrings.appInfoReadFailed,
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
            title: AppStrings.streamServiceTitle,
            description: AppStrings.streamServiceDescription,
          ),
          network.when(
            loading: () => const _InfoCard(
              icon: Icons.network_check,
              text: AppStrings.checkingNetwork,
            ),
            error: (error, _) => const _InfoCard(
              icon: Icons.signal_wifi_bad,
              text: AppStrings.networkListenFailed,
            ),
            data: (status) => _InfoCard(
              icon: status.isConnected ? Icons.wifi : Icons.wifi_off,
              text: _networkLabel(status.type),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(appInfoProvider),
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.reloadAppInfo),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text(AppStrings.logout),
          ),
        ],
      ),
    );
  }

  String _networkLabel(NetworkConnectionType type) {
    return AppStrings.currentConnection(_networkTypeLabel(type));
  }

  String _networkTypeLabel(NetworkConnectionType type) => switch (type) {
    NetworkConnectionType.wifi => AppStrings.connectionWifi,
    NetworkConnectionType.mobile => AppStrings.connectionMobile,
    NetworkConnectionType.ethernet => AppStrings.connectionEthernet,
    NetworkConnectionType.bluetooth => AppStrings.connectionBluetooth,
    NetworkConnectionType.satellite => AppStrings.connectionSatellite,
    NetworkConnectionType.vpn => AppStrings.connectionVpn,
    NetworkConnectionType.other => AppStrings.connectionOther,
    NetworkConnectionType.none => AppStrings.connectionNone,
  };

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
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
