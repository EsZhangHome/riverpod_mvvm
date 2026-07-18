// “我的”页面中的隐私升级模拟入口。
//
// View 只展示状态并发送 simulateNextUpgrade 命令。政策版本比较、Dialog、持久化和
// 拒绝后退出登录全部复用企业底座实现，不在 Demo 页面复制业务逻辑。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';
import 'package:riverpod_mvvm/shared/theme/app_spacing.dart';

import '../../../localization/demo_strings.dart';
import '../view_model/privacy_policy_simulator.dart';

/// 展示当前/历史隐私版本，并提供一次模拟升级操作。
final class PrivacyUpgradeDemoCard extends ConsumerWidget {
  const PrivacyUpgradeDemoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 卡片读取底座最终状态，而不是只读取模拟器 state。这样显示内容与全局 Dialog
    // 使用的是同一事实来源，可以观察 Provider override 如何影响正式业务 Provider。
    final consent = ref.watch(privacyConsentProvider);
    final acceptedVersion = consent.acceptedRecord?.consentVersion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.policy_outlined),
              title: Text(DemoStrings.privacyUpgradeSimulationTitle),
              subtitle: Text(DemoStrings.privacyUpgradeSimulationDescription),
            ),
            Text(
              DemoStrings.currentPrivacyPolicyVersion(consent.policy.version),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              DemoStrings.acceptedPrivacyPolicyVersion(
                acceptedVersion ?? DemoStrings.noAcceptedPrivacyPolicy,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const ValueKey('demo.simulatePrivacyUpgrade'),
                // 已进入业务首页说明通常已同意当前版本。额外判断可以防止测试或异常
                // 路由直接打开本页时，在未授权状态上制造含义不清的第二次升级。
                onPressed: consent.hasAcceptedCurrentPolicy
                    ? () => ref
                          .read(demoPrivacyPolicyConfigProvider.notifier)
                          .simulateNextUpgrade()
                    : null,
                icon: const Icon(Icons.upgrade),
                label: const Text(DemoStrings.simulatePrivacyPolicyUpgrade),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
