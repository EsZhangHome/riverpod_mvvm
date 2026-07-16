import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure_observer.dart';
import '../../../l10n/app_localizations.dart';
import '../model/privacy_consent_state.dart';
import '../model/privacy_prompt_state.dart';
import '../privacy_consent_providers.dart';
import '../view_model/privacy_consent_view_model.dart';
import '../view_model/privacy_prompt_coordinator.dart';
import 'privacy_policy_dialog.dart';

/// 整个 App 唯一的隐私政策弹窗 Presenter。
///
/// 为什么使用 ConsumerStatefulWidget：
/// - Riverpod 保存“是否需要弹、正在保存、谁在等待结果”等可测试状态；
/// - Flutter DialogRoute 必须由有生命周期的 Widget 使用 Navigator 创建和释放；
/// - State 持有当前 Route 引用，可以在路由切换、Provider 更新时精确关闭这一层，
///   不会误 pop 业务页。
///
/// 首次自动提示、登录动作再次触发和政策升级全部经过本 Presenter。Notifier 从不
/// 持有 BuildContext，登录页也不再创建第二套 showDialog，MVVM 与 Riverpod 边界
/// 保持清晰。
final class PrivacyConsentHost extends ConsumerStatefulWidget {
  const PrivacyConsentHost({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.showInitialConsent,
    required this.onDeclineUpgrade,
  });

  /// 原始 Router/网络反馈组件。DialogRoute 显示在它使用的根 Navigator 上方。
  final Widget child;

  /// GoRouter 与本 Presenter 共用的根 Navigator key。
  ///
  /// MaterialApp.builder 的 context 位于 Navigator 外层，不能靠向下查找获得 Navigator；
  /// 显式注入同一个 key 才能稳定定位真正管理业务路由的根导航器。
  final GlobalKey<NavigatorState> navigatorKey;

  /// 是否已经确认认证恢复结束且当前显示登录页，可以安全展示首次提示。
  ///
  /// 该值由 App 组合层根据 AuthState 注入。这样 Dialog 不会覆盖会话恢复页，也不会
  /// 在已有登录会话时把“首次授权”和“政策升级”混为一谈。
  final bool showInitialConsent;

  /// 拒绝政策升级后的会话清理动作，由 App 组合层注入 AuthNotifier.logout。
  final Future<void> Function() onDeclineUpgrade;

  @override
  ConsumerState<PrivacyConsentHost> createState() => _PrivacyConsentHostState();
}

final class _PrivacyConsentHostState extends ConsumerState<PrivacyConsentHost> {
  late final ProviderSubscription<PrivacyConsentState> _consentSubscription;
  late final ProviderSubscription<PrivacyPromptState> _promptSubscription;

  DialogRoute<void>? _activeRoute;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _consentSubscription = ref.listenManual<PrivacyConsentState>(
      privacyConsentProvider,
      (_, _) => _scheduleSynchronize(),
      fireImmediately: true,
    );
    _promptSubscription = ref.listenManual<PrivacyPromptState>(
      privacyPromptCoordinatorProvider,
      (_, _) => _scheduleSynchronize(),
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant PrivacyConsentHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigatorKey != widget.navigatorKey ||
        oldWidget.showInitialConsent != widget.showInitialConsent) {
      _scheduleSynchronize();
    }
  }

  @override
  Widget build(BuildContext context) {
    // child 自己就是 Router，不在这里再包 Stack/Overlay。弹窗由根 Navigator 的
    // DialogRoute 管理，自动获得 Material 动画、SafeArea、焦点闭环与语义屏障。
    _scheduleSynchronize();
    return widget.child;
  }

  void _scheduleSynchronize() {
    if (_syncScheduled || !mounted) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _synchronizeRoute();
    });
  }

  void _synchronizeRoute() {
    final consent = ref.read(privacyConsentProvider);
    final prompt = ref.read(privacyPromptCoordinatorProvider);
    final shouldShow = _shouldShow(consent, prompt);

    if (!shouldShow) {
      _closeActiveRoute();
      return;
    }
    if (_activeRoute != null) return;

    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      // MaterialApp 首次构建时 Navigator 可能还没有挂载。下一帧重试，不创建额外
      // Timer，也不会让 Provider 承担 Widget 生命周期。
      _scheduleSynchronize();
      return;
    }

    final route = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      settings: const RouteSettings(name: '/privacy-consent'),
      builder: (_) => Consumer(
        builder: (context, ref, child) {
          final currentConsent = ref.watch(privacyConsentProvider);
          final currentPrompt = ref.watch(privacyPromptCoordinatorProvider);
          return _buildDialog(context, currentConsent, currentPrompt);
        },
      ),
    );
    _activeRoute = route;
    unawaited(
      navigator.push<void>(route).whenComplete(() {
        if (_activeRoute == route) _activeRoute = null;
        _scheduleSynchronize();
      }),
    );
  }

  bool _shouldShow(PrivacyConsentState consent, PrivacyPromptState prompt) {
    final shouldShowInitial =
        widget.showInitialConsent &&
        consent.status == PrivacyConsentStatus.initialConsentRequired;
    return shouldShowInitial ||
        consent.shouldShowPolicyUpgrade ||
        prompt.hasPendingRequest;
  }

  Widget _buildDialog(
    BuildContext context,
    PrivacyConsentState consent,
    PrivacyPromptState prompt,
  ) {
    final strings = AppLocalizations.of(context);
    final isUpgrade =
        consent.status == PrivacyConsentStatus.policyUpgradeRequired ||
        consent.status == PrivacyConsentStatus.upgradeDeclinedForSession;
    final isBusy = consent.isSaving || prompt.isHandlingDecline;

    return PopScope(
      // 系统返回键、iOS 返回手势和点击遮罩都不能被当作同意。用户必须使用明确按钮。
      canPop: false,
      child: PrivacyPolicyDialog(
        state: consent,
        isBusy: isBusy,
        declineActionFailed: prompt.declineFailed,
        title: isUpgrade
            ? strings.privacyPolicyUpgradeTitle
            : strings.privacyConsentTitle,
        introduction: _introduction(strings, isUpgrade, prompt),
        agreeLabel: prompt.hasPendingRequest
            ? strings.agreeAndContinue
            : isUpgrade
            ? strings.agreeAndContinueUsing
            : strings.agreeAndContinue,
        declineLabel: prompt.hasPendingRequest
            ? strings.disagree
            : isUpgrade
            ? strings.declineAndLogout
            : strings.disagree,
        onOpenPolicy: () => ref
            .read(privacyPolicyLauncherProvider)
            .open(Uri.parse(consent.policy.url)),
        onOpenUserAgreement: () => ref
            .read(privacyPolicyLauncherProvider)
            .open(Uri.parse(consent.policy.userAgreementUrl)),
        onAgree: () => unawaited(_accept()),
        onDecline: () => unawaited(_decline(isUpgrade, prompt)),
      ),
    );
  }

  String _introduction(
    AppLocalizations strings,
    bool isUpgrade,
    PrivacyPromptState prompt,
  ) {
    if (!isUpgrade) {
      return prompt.hasPendingRequest
          ? strings.privacyLoginConsentIntroduction
          : strings.privacyInitialConsentIntroduction;
    }
    return prompt.hasPendingRequest
        ? strings.privacyPolicyUpgradeLoginIntroduction
        : strings.privacyPolicyUpgradeIntroduction;
  }

  Future<void> _accept() async {
    if (ref.read(privacyPromptCoordinatorProvider).isHandlingDecline) return;
    final accepted = await ref
        .read(privacyConsentProvider.notifier)
        .acceptCurrentPolicy();
    if (!accepted || !mounted) return;
    ref
        .read(privacyPromptCoordinatorProvider.notifier)
        .resolveLoginRequest(true);
  }

  Future<void> _decline(bool isUpgrade, PrivacyPromptState promptAtTap) async {
    final coordinator = ref.read(privacyPromptCoordinatorProvider.notifier);

    // 登录页未勾选触发的显式请求被拒绝时，只完成等待中的 Future。LoginPage 收到
    // false 后会取消勾选，不修改磁盘授权事实，也不会发出登录请求。
    if (promptAtTap.hasPendingRequest) {
      coordinator.resolveLoginRequest(false);
      return;
    }

    // 没有 pending 且不是升级，说明这是首次进入登录页的自动提示。拒绝只改变本次
    // 运行的内存状态，让 Dialog 关闭并保持复选框未选中；绝不保存“已同意”。
    if (!isUpgrade) {
      ref
          .read(privacyConsentProvider.notifier)
          .dismissInitialConsentForCurrentSession();
      return;
    }

    if (!coordinator.beginDeclineAction()) return;
    try {
      // 保持 policyUpgradeRequired 不变，所以 Dialog 在 logout 和安全存储清理全部完成
      // 前始终遮挡业务页。完成后才切换内存状态并关闭，不会短暂闪回受保护内容。
      await widget.onDeclineUpgrade();
      if (!mounted) return;
      ref
          .read(privacyConsentProvider.notifier)
          .declineUpgradeForCurrentSession();
      coordinator.finishDeclineAction(succeeded: true);
    } catch (error, stackTrace) {
      FailureObserver.reportIfNeeded(error, stackTrace);
      if (mounted) coordinator.finishDeclineAction(succeeded: false);
    }
  }

  void _closeActiveRoute() {
    final route = _activeRoute;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      // 极端情况下若其他路由已经盖在上面，只移除我们自己保存的 DialogRoute，不能
      // 使用普通 pop 误关业务页。
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _consentSubscription.close();
    _promptSubscription.close();
    final route = _activeRoute;
    final navigator = route?.navigator;
    if (route != null && navigator != null && route.isActive) {
      navigator.removeRoute(route);
    }
    super.dispose();
  }
}
