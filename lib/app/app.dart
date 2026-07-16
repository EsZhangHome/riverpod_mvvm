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

  /// 防止登录、退出等后续状态变化重复安排“会话完成后”阶段。
  bool _sessionWarmupScheduled = false;

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
    ).config;

    // fireImmediately 先把 restoring 快照交给回调；它只刷新守卫，不会启动 Warmup。
    // 当安全会话真正恢复完成后，回调会通知路由并把非关键任务安排到目标页首帧之后。
    _authSubscription = ref.listenManual<AuthState>(
      authProvider,
      _onAuthStateChanged,
      fireImmediately: true,
    );

    // 监控等 early 任务只等待 MyApp 第一帧，不等待安全会话。任务通过 phase 显式
    // 选择这个时机，远程配置等默认任务不会在这里被提前执行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(appWarmupProvider.notifier)
            .startPhase(AppWarmupPhase.afterFirstFrame),
      );
    });
  }

  /// 认证状态变化时同时处理路由刷新和非关键预热触发。
  ///
  /// [previous] 是上一次 AuthState；首次 fireImmediately 时为 null。[next] 是最新状态。
  /// 路由通知必须立即发送；Warmup 则等 restoring 结束并再等一帧，避免监控、远程配置
  /// 等任务与 SecureStorage 读取争抢启动期资源。
  void _onAuthStateChanged(AuthState? previous, AuthState next) {
    _routerRefresh.notify();
    if (next.isRestoringSession || _sessionWarmupScheduled) return;
    _sessionWarmupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // read 只发送一次命令，不监听预热进度，因此根 Widget 不会为后台状态重建。
      unawaited(
        ref
            .read(appWarmupProvider.notifier)
            .startPhase(AppWarmupPhase.afterSessionReady),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 组合认证状态与网络客户端。这里只建立回调关系，不发请求，也不初始化重型 SDK。
    ref.watch(authNetworkBindingProvider);

    // 监听主题变化，MaterialApp 会在主题切换时正确重建
    final themeState = ref.watch(themeProvider);

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
        return AppNetworkFeedback(
          navigatorKey: _navigatorKey,
          child: child ?? const SizedBox.shrink(),
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
    // 三个对象都由当前 State 创建，因此也必须在相同生命周期边界释放。
    // 先停止 Provider 回调，再释放 GoRouter 和它订阅的 refreshListenable。
    _authSubscription.close();
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
