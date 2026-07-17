// lib/app/app.dart
//
// 作用：App 的根 Widget，负责主题、路由和国际化。
//
// 组件层次：
// MyApp（接收入口提供的 AppRouteBundle）
//   └── _AppView（ConsumerStatefulWidget，缓存 GoRouter）
//        └── MaterialApp.router

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/env_config.dart';
import '../features/auth/auth.dart';
import '../features/privacy_consent/privacy_consent.dart';
import '../l10n/app_localizations.dart';
import '../shared/theme/theme_provider.dart';
import 'bootstrap/app_warmup.dart';
import 'network/app_network_feedback.dart';
import 'navigation/app_route_bundle.dart';
import 'navigation/app_router.dart';
import 'navigation/route_guard.dart';

/// App 的根 Widget。
///
/// ProviderScope 由 BootstrapGate 在启动完成后提供，这里只组装应用级 Widget。
/// MyApp 不 import 具体业务页面；业务路由通过 routeBundle 注入，客户替换首页
/// 或增加业务模块时不需要修改通用路由器。
class MyApp extends StatelessWidget {
  /// 创建 App 根组件。
  ///
  /// [routeBundle] 由 BootstrapGate 从 main.dart 一路透传，并且必须显式提供。
  /// 通用 App 不再内置 Starter 默认值，因此删除 Starter 组件后不会留下隐式依赖。
  const MyApp({super.key, required this.routeBundle});

  /// 入口层提供的路由组合。
  /// _AppView 会把其中的首页、登录入口和保护规则交给 AuthRouteGuard，把 routes
  /// 交给 AppRouter，因此这里是同一份路由配置的传递点，不拥有路由业务逻辑。
  final AppRouteBundle routeBundle;

  @override
  Widget build(BuildContext context) {
    return _AppView(routeBundle: routeBundle);
  }
}

/// 内部 StatefulWidget，负责持有 GoRouter 实例并桥接 Riverpod。
///
/// GoRouter 实例必须保持稳定（不能每次 rebuild 都重新创建）。
/// 通过 ref.listenManual 监听 authProvider 状态变化，触发 GoRouter 的
/// refreshListenable，并按认证阶段调度 Warmup。
class _AppView extends ConsumerStatefulWidget {
  const _AppView({required this.routeBundle});

  final AppRouteBundle routeBundle;

  @override
  ConsumerState<_AppView> createState() => _AppViewState();
}

class _AppViewState extends ConsumerState<_AppView> {
  /// 根 Navigator 的稳定身份键。
  ///
  /// MaterialApp.builder 位于 Navigator 外层，无法通过自己的 BuildContext 向下查找
  /// Overlay。把同一个 key 交给 GoRouter 和 AppNetworkFeedback 后，全局网络监听可
  /// 使用与业务页面相同的根 Overlay 展示真正的 AppToast。
  late final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();

  /// 桥接 Riverpod → GoRouter：AuthState 变化时通知 GoRouter 重新执行 redirect
  late final _routerRefresh = _RouterRefreshNotifier();

  /// GoRouter 实例，整个生命周期只创建一次。
  late final GoRouter _router;

  /// initState 中创建的认证订阅。
  ///
  /// Riverpod 3 的 listenManual 专门用于 Widget 生命周期方法。它比在 build 中反复
  /// 声明 ref.listen 更明确，也确保路由器创建后立即开始接收认证状态变化。
  late final ProviderSubscription<AuthState> _authSubscription;

  /// 隐私政策状态订阅。
  ///
  /// 首次授权时 MyApp 已经显示登录页，但登录请求尚未放行；政策升级时 MyApp 保留
  /// 当前业务路由。两种情况都在用户同意当前版本后才放行 Warmup，避免提前初始化
  /// 统计、推送等需要授权的 SDK。
  late final ProviderSubscription<PrivacyConsentState> _privacySubscription;

  /// 防止登录、退出等后续状态变化重复安排“会话完成后”阶段。
  bool _sessionWarmupScheduled = false;

  /// MyApp 是否已经绘制首帧。它与隐私状态共同决定 afterFirstFrame 能否开始。
  bool _firstFrameRendered = false;

  /// 防止隐私状态重建后重复启动首帧预热阶段。
  bool _firstFrameWarmupScheduled = false;

  /// 安全会话是否已完成恢复。只有它与隐私授权同时满足才启动会话后预热。
  bool _sessionRestored = false;

  @override
  void initState() {
    super.initState();
    // Guard 只接收读取 AuthState 的函数，不再通过 BuildContext 反查
    // ProviderScope。这样依赖来源更明确，守卫也可以脱离 Widget 单元测试。
    _router = AppRouter(
      refreshListenable: _routerRefresh,
      guards: [
        AuthRouteGuard(
          () => ref.read(authProvider),
          authenticatedHome: widget.routeBundle.authenticatedHome,
          loginPath: widget.routeBundle.loginPath,
          protectedPaths: widget.routeBundle.protectedPaths,
          protectedPrefixes: widget.routeBundle.protectedPrefixes,
        ),
      ],
      routeBundle: widget.routeBundle,
      navigatorKey: _navigatorKey,
      // 默认登录页在真正发请求前请求隐私授权。App 层同时知道 Auth 与 Privacy，
      // 适合在这里完成组合；两个 Feature 自身不互相 import，保持依赖单向。
      defaultLoginBuilder: (context, state) => LoginPage(
        beforeLogin: requestPrivacyConsentBeforeLogin,
        openAgreement: (context, document) => switch (document) {
          LoginAgreementDocument.privacyPolicy => openPrivacyPolicyDocument(
            context,
          ),
          LoginAgreementDocument.userAgreement => openUserAgreementDocument(
            context,
          ),
        },
      ),
    ).config;

    // fireImmediately 先把 restoring 快照交给回调；它只刷新守卫，不会启动 Warmup。
    // 当安全会话真正恢复完成后，回调会通知路由并把非关键任务安排到目标页首帧之后。
    _authSubscription = ref.listenManual<AuthState>(
      authProvider,
      _onAuthStateChanged,
      fireImmediately: true,
    );

    _privacySubscription = ref.listenManual<PrivacyConsentState>(
      privacyConsentProvider,
      _onPrivacyConsentChanged,
      fireImmediately: true,
    );

    // 监控等 early 任务只等待 MyApp 第一帧，不等待安全会话。任务通过 phase 显式
    // 选择这个时机，远程配置等默认任务不会在这里被提前执行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firstFrameRendered = true;
      _scheduleWarmupWhenAllowed();
    });
  }

  /// 认证状态变化时同时处理路由刷新和非关键预热触发。
  ///
  /// [previous] 是上一次 AuthState；首次 fireImmediately 时为 null。[next] 是最新状态。
  /// 路由通知必须立即发送；Warmup 则等 restoring 结束并再等一帧，避免监控、远程配置
  /// 等任务与 SecureStorage 读取争抢启动期资源。
  void _onAuthStateChanged(AuthState? previous, AuthState next) {
    _routerRefresh.notify();
    _sessionRestored = !next.isRestoringSession;
    _scheduleWarmupWhenAllowed();
  }

  /// 隐私状态改变时重新判断延迟初始化是否可以执行。
  ///
  /// policyUpgradeRequired 和 upgradeDeclinedForSession 都没有同意当前版本，因此不会
  /// 启动尚未执行的 Warmup。已经运行过的第三方 SDK 无法由底座通用反初始化，真实
  /// SDK 若支持停止采集，应在项目自己的拒绝升级回调中额外调用其关闭方法。
  void _onPrivacyConsentChanged(
    PrivacyConsentState? previous,
    PrivacyConsentState next,
  ) {
    // 登录页复选框只表示本次页面会话的选择，不能在政策失效后继续保持旧的 true。
    // 因此撤回同意、发现升级或拒绝升级时立即取消；从未同意/旧版本变为当前版本
    // 时（例如在升级弹窗中点击同意）再同步选中。fireImmediately 的 previous 为
    // null，此时故意不把历史磁盘记录自动映射成页面已勾选。
    final agreement = ref.read(loginAgreementSelectionProvider.notifier);
    if (!next.hasAcceptedCurrentPolicy) {
      agreement.unselect();
    } else if (previous != null && !previous.hasAcceptedCurrentPolicy) {
      agreement.setSelected(true);
    }
    _scheduleWarmupWhenAllowed();
  }

  /// 同时满足“界面时机”和“已同意当前政策”后才启动对应 Warmup 阶段。
  void _scheduleWarmupWhenAllowed() {
    if (!mounted ||
        !ref.read(privacyConsentProvider).hasAcceptedCurrentPolicy) {
      return;
    }

    if (_firstFrameRendered && !_firstFrameWarmupScheduled) {
      _firstFrameWarmupScheduled = true;
      unawaited(
        ref
            .read(appWarmupProvider.notifier)
            .startPhase(AppWarmupPhase.afterFirstFrame),
      );
    }

    if (_sessionRestored && !_sessionWarmupScheduled) {
      _sessionWarmupScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // 再等目标页一帧，避免远程配置等后台工作与登录页/首页首次布局争抢资源。
        unawaited(
          ref
              .read(appWarmupProvider.notifier)
              .startPhase(AppWarmupPhase.afterSessionReady),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 组合认证状态与网络客户端。这里只建立回调关系，不发请求，也不初始化重型 SDK。
    ref.watch(authNetworkBindingProvider);

    // 监听主题变化，MaterialApp 会在主题切换时正确重建
    final themeState = ref.watch(themeProvider);
    // 首次自动提示必须等安全会话恢复结束，并确认路由进入未登录状态。select 只关注
    // 认证阶段，token 等无关字段变化不会让根 MaterialApp 重建。
    final showInitialPrivacyConsent = ref.watch(
      authProvider.select(
        (state) => state.status == AuthStatus.unauthenticated,
      ),
    );
    return MaterialApp.router(
      title: EnvConfig.appName,
      debugShowCheckedModeBanner: false,

      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,
      themeMode: themeState.themeMode,

      routerConfig: _router,

      // builder 位于 MaterialApp 提供的 Theme、ScaffoldMessenger 和本地化环境内。
      // 网络监听因此可以使用统一 AppToast，但 child（Router）仍被原样返回，不改变
      // 导航层级。系统连接状态由 Riverpod Provider 注入，测试可完全替换。这里不再
      // 根据接口耗时推断弱网，避免把服务端计算慢错误提示成用户网络差。
      builder: (context, child) {
        return PrivacyConsentHost(
          navigatorKey: _navigatorKey,
          showInitialConsent: showInitialPrivacyConsent,
          // 隐私 Feature 不直接 import Auth；应用组合层在这里把“拒绝升级”连接到
          // AuthNotifier。logout 会立即清内存状态，GoRouter 自动返回登录页。
          onDeclineUpgrade: () => ref
              .read(authProvider.notifier)
              .logout(requirePersistentClear: true),
          child: AppNetworkFeedback(
            navigatorKey: _navigatorKey,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  @override
  void dispose() {
    // 两个订阅、路由器和刷新通知器都由当前 State 创建，因此也必须在相同生命周期
    // 边界释放。
    // 先停止 Provider 回调，再释放 GoRouter 和它订阅的 refreshListenable。
    _authSubscription.close();
    _privacySubscription.close();
    _router.dispose();
    _routerRefresh.dispose();
    super.dispose();
  }
}

/// 最小 ChangeNotifier，仅用于桥接 Riverpod 的 listenManual 到 GoRouter 的
/// refreshListenable。
class _RouterRefreshNotifier extends ChangeNotifier {
  /// 通知 GoRouter 认证状态已经变化，需要重新调用 redirect。
  /// 不在这里携带 AuthState，Guard 会在执行时读取最新值，避免状态重复保存。
  void notify() => notifyListeners();
}
