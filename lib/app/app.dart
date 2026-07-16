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
import 'navigation/app_route_bundle.dart';
import 'navigation/app_router.dart';
import 'navigation/route_guard.dart';

/// App 的根 Widget。
///
/// ProviderScope 由 BootstrapGate 在启动完成后提供，这里只组装应用级 Widget。
/// MyApp 不 import 具体业务页面；业务路由通过 routeBundle 注入，客户替换首页
/// 或增加业务模块时不需要修改通用路由器。
class MyApp extends StatelessWidget {
  const MyApp({super.key, this.routeBundle = const AppRouteBundle.starter()});

  /// 入口层提供的路由组合。
  /// 默认值是企业底座的 StarterPage，便于新项目先验证基础设施再接业务首页。
  final AppRouteBundle routeBundle;

  @override
  Widget build(BuildContext context) {
    return _AppView(routeBundle: routeBundle);
  }
}

/// 内部 StatefulWidget，负责持有 GoRouter 实例并桥接 Riverpod。
///
/// GoRouter 实例必须保持稳定（不能每次 rebuild 都重新创建）。
/// 通过 ref.listen 监听 authProvider 状态变化，触发 GoRouter 的 refreshListenable。
class _AppView extends ConsumerStatefulWidget {
  const _AppView({required this.routeBundle});

  final AppRouteBundle routeBundle;

  @override
  ConsumerState<_AppView> createState() => _AppViewState();
}

class _AppViewState extends ConsumerState<_AppView> {
  /// 桥接 Riverpod → GoRouter：AuthState 变化时通知 GoRouter 重新执行 redirect
  late final _routerRefresh = _RouterRefreshNotifier();

  /// GoRouter 实例，整个生命周期只创建一次。
  late final GoRouter _router;

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
    ).config;

    // addPostFrameCallback 保证 MaterialApp 至少完成第一帧后才开始非关键预热。
    // 这里使用 read 发命令，不 watch 状态，因此预热进度不会让根 Widget 重建。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(appWarmupProvider.notifier).start());
    });
  }

  @override
  Widget build(BuildContext context) {
    // 组合认证状态与网络客户端。这里只建立回调关系，不发请求，也不初始化重型 SDK。
    ref.watch(authNetworkBindingProvider);

    // 监听 AuthState 变化 → 通知 GoRouter 刷新路由守卫
    // 注意：ref.listen 必须在 build 中调用，不能在 initState 中使用
    ref.listen(authProvider, (prev, next) {
      _routerRefresh.notify();
    });

    // 监听主题变化，MaterialApp 会在主题切换时正确重建
    final themeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: EnvConfig.appName,
      debugShowCheckedModeBanner: false,

      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,
      themeMode: themeState.themeMode,

      routerConfig: _router,

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
    // 两个对象都由当前 State 创建，因此也必须由当前 State 释放。
    // 先释放 GoRouter，让它停止监听 refreshListenable，再释放桥接对象。
    _router.dispose();
    _routerRefresh.dispose();
    super.dispose();
  }
}

/// 最小 ChangeNotifier，仅用于桥接 Riverpod 的 ref.listen 到 GoRouter 的 refreshListenable。
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
