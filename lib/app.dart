// lib/app.dart
//
// 作用：App 的根 Widget，负责主题、路由和国际化。
//
// 迁移说明（Provider → Riverpod）：
// - MultiProvider → ProviderScope（在 main.dart 中）
// - ChangeNotifierProvider<AuthProvider> → authProvider（NotifierProvider）
// - ChangeNotifierProvider<ThemeProvider> → themeProvider（NotifierProvider）
// - Consumer<ThemeProvider> → ref.watch(themeProvider)
// - context.read<AuthProvider> → ref.read(authProvider)
//
// 组件层次：
// MyApp（ConsumerWidget）
//   └── _AppView（ConsumerStatefulWidget，缓存 GoRouter）
//        └── MaterialApp.router

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/router/route_guard.dart';
import 'global/auth_provider.dart';
import 'global/theme_provider.dart';

/// App 的根 Widget。
///
/// 不需要 MultiProvider，ProviderScope 在 main.dart 中提供。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppView();
  }
}

/// 内部 StatefulWidget，负责持有 GoRouter 实例并桥接 Riverpod。
///
/// GoRouter 实例必须保持稳定（不能每次 rebuild 都重新创建）。
/// 通过 ref.listen 监听 AuthProvider 变化，触发 GoRouter 的 refreshListenable。
class _AppView extends ConsumerStatefulWidget {
  const _AppView();

  @override
  ConsumerState<_AppView> createState() => _AppViewState();
}

class _AppViewState extends ConsumerState<_AppView> {
  /// 桥接 Riverpod → GoRouter：AuthProvider 变化时通知 GoRouter 重新执行 redirect
  late final _routerRefresh = _RouterRefreshNotifier();

  /// GoRouter 实例，整个生命周期只创建一次
  late final _router = AppRouter(
    refreshListenable: _routerRefresh,
    guards: [const AuthRouteGuard()],
  ).config;

  @override
  Widget build(BuildContext context) {
    // 监听 AuthProvider 变化 → 通知 GoRouter 刷新路由守卫
    // 注意：ref.listen 必须在 build 中调用，不能在 initState 中使用
    ref.listen(authProvider, (prev, next) {
      _routerRefresh.notify();
    });

    // 监听主题变化，MaterialApp 会在主题切换时正确重建
    final themeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'MVVM Demo',
      debugShowCheckedModeBanner: false,

      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,
      themeMode: themeState.themeMode,

      routerConfig: _router,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
    );
  }
}

/// 最小 ChangeNotifier，仅用于桥接 Riverpod 的 ref.listen 到 GoRouter 的 refreshListenable。
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
