// lib/app/network/app_network_feedback.dart
//
// 作用：在 MaterialApp 内部监听全局连接状态和真实请求质量，并给用户轻量提示。
//
// 这个组件属于 app 组合层，而不是 core/network：core 只产生与 Flutter 无关的数据；
// AppNetworkFeedback 才把 Riverpod 状态转换成 Toast。这样网络基础设施不会持有
// BuildContext，也不会因为 UI 样式变化而被迫修改。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_quality_monitor.dart';
import '../../core/network/network_status_service.dart';
import '../../core/providers/service_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/ui/app_toast.dart';

/// App 级网络反馈边界。
///
/// [child] 通常是 MaterialApp.router 交给 builder 的 Router。组件不改变页面布局，
/// 只通过 `ref.listen` 执行一次性 Toast 副作用，因此网络变化不会重建整棵路由树。
class AppNetworkFeedback extends ConsumerStatefulWidget {
  /// 创建网络反馈边界。
  ///
  /// [navigatorKey] 必须与 GoRouter 的 navigatorKey 是同一个对象，用于取得根
  /// Overlay；[child] 必须原样放回 Widget 树，不能遗漏 Router。
  const AppNetworkFeedback({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// GoRouter 根 Navigator 的稳定身份键。
  final GlobalKey<NavigatorState> navigatorKey;

  /// MaterialApp.router 创建的导航内容。
  final Widget child;

  @override
  ConsumerState<AppNetworkFeedback> createState() => _AppNetworkFeedbackState();
}

class _AppNetworkFeedbackState extends ConsumerState<AppNetworkFeedback> {
  /// 最近一次连接状态。
  ///
  /// null 表示 Provider 还没有返回首值。首值是在线时不弹“网络已恢复”，否则每次
  /// 正常启动都会产生无意义提示；首值是离线时仍需要立即提醒用户。
  NetworkStatus? _lastStatus;

  @override
  Widget build(BuildContext context) {
    // 监听系统网络连接类型。AsyncValue.loading/error 不直接 Toast：插件查询失败不等于
    // 用户真的断网，真实接口错误仍会按正常错误链路反馈。
    ref.listen<AsyncValue<NetworkStatus>>(networkStatusProvider, (
      previous,
      next,
    ) {
      next.whenData(_handleConnectionStatus);
    });

    // 监听真实接口样本产生的质量跨级事件。StreamProvider 只在事件到来时通知，不会
    // 因为每一个请求耗时都触发页面重建。
    ref.listen<AsyncValue<NetworkQualityEvent>>(networkQualityEventsProvider, (
      previous,
      next,
    ) {
      next.whenData(_handleQualityEvent);
    });

    return widget.child;
  }

  void _handleConnectionStatus(NetworkStatus next) {
    if (!mounted) return;
    final previous = _lastStatus;
    _lastStatus = next;
    final overlay = _rootOverlay;
    if (overlay == null) return;
    final strings = AppLocalizations.of(context);

    if (!next.isConnected) {
      // 首次查询就是离线，或从在线切到离线，都应提醒；Provider 已通过 distinct
      // 过滤相同状态，所以不会因插件重复上报而连续弹相同 Toast。
      AppToast.showError(
        context,
        strings.networkDisconnected,
        position: AppToastPosition.top,
        displayDuration: const Duration(seconds: 4),
        overlay: overlay,
      );
      return;
    }

    // App 启动时首值在线不提示；只有明确经历过 none → connected 才提示恢复。
    if (previous != null && !previous.isConnected) {
      AppToast.showSuccess(
        context,
        strings.networkRestored,
        position: AppToastPosition.top,
        overlay: overlay,
      );
    }
  }

  void _handleQualityEvent(NetworkQualityEvent event) {
    if (!mounted) return;
    final overlay = _rootOverlay;
    if (overlay == null) return;

    // 系统已经明确报告离线时，离线 Toast 信息更准确，不再叠加“网络较慢”。
    if (_lastStatus?.isConnected == false) return;
    final strings = AppLocalizations.of(context);

    switch (event.quality) {
      case NetworkQuality.poor:
        AppToast.showWarning(
          context,
          strings.networkPoor,
          position: AppToastPosition.top,
          displayDuration: const Duration(seconds: 4),
          overlay: overlay,
        );
        break;
      case NetworkQuality.good:
        // Monitor 只会在 poor 后恢复时发布 good，初次快速请求不会产生恢复提示。
        AppToast.showSuccess(
          context,
          strings.networkQualityRestored,
          position: AppToastPosition.top,
          overlay: overlay,
        );
        break;
      case NetworkQuality.unknown:
        // unknown 只是样本不足，不属于需要打扰用户的状态。
        break;
    }
  }

  /// builder 的 context 位于 Navigator 外层，无法向下查找 Overlay；根 key 可以直接
  /// 取得 OverlayState，交给 AppToast 的显式组合层入口，不再做无效的 context 绕行。
  OverlayState? get _rootOverlay => widget.navigatorKey.currentState?.overlay;
}
