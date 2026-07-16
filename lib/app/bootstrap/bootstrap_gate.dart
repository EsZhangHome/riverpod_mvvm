// lib/app/bootstrap/bootstrap_gate.dart
//
// 为什么业务 ProviderScope 不直接放在 main.dart：themeProvider 首次构建会同步
// 读取 LocalStorage；SessionStore 迁移旧会话时也可能读取旧用户偏好。如果普通
// 存储还没完成初始化，这两类恢复结果可能不准确。
// BootstrapGate 只等待配置和最小存储；数据库、监控等非关键能力不会阻塞这里。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env_config.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/ui/loading_view.dart';
import '../app.dart';
import '../navigation/app_route_bundle.dart';
import 'app_bootstrap.dart';

/// 将启动结果注入 Riverpod。业务可读取是否 degraded，而不依赖 BootstrapGate。
final bootstrapResultProvider = Provider<BootstrapResult>(
  (ref) => const BootstrapResult.ready(),
);

/// 业务 Widget 树前面的“启动门”。
///
/// 它解决两个时序问题：
/// 1. 先显示一个最小启动界面，再等待关键初始化，避免原生启动图长时间白屏；
/// 2. 只有 LocalStorage 已尝试初始化后才创建业务 ProviderScope，避免主题恢复和
///    旧会话迁移过早读取普通存储。
///
/// [bootstrap] 可在测试中替换；[routeBundle] 由具体项目入口注入业务路由。
class BootstrapGate extends StatefulWidget {
  /// 创建启动门。
  ///
  /// - [bootstrap]：可选的启动用例。正式运行为空即可；Widget 测试可注入假实现，
  ///   避免启动真实 SharedPreferences；
  /// - [routeBundle]：当前项目的完整路由组合，启动成功后原样传给 MyApp；
  /// - [key]：Flutter 标准 Widget 标识，通常无需传入。
  const BootstrapGate({super.key, this.bootstrap, required this.routeBundle});

  /// 可替换的关键启动用例；null 时在首次启动或重试时创建默认 AppBootstrap。
  final AppBootstrap? bootstrap;

  /// 当前项目的业务路由组合。
  /// 该对象一路传给 MyApp，不使用全局可变变量，测试也能显式替换。
  final AppRouteBundle routeBundle;

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate> {
  /// Future 保存在 State 中，避免 FutureBuilder 每次 build 都重新执行初始化。
  late Future<BootstrapResult> _future;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    // 重试时创建一个新 Future；setState 后 FutureBuilder 才会重新订阅。
    _future = (widget.bootstrap ?? AppBootstrap()).initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapResult>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // 启动失败也会被 AppBootstrap 转成 BootstrapResult，因此这里只表示等待中。
          return const _BootstrapMaterialApp(child: LoadingView());
        }

        final result = snapshot.data!;
        if (!result.canStart) {
          return _BootstrapMaterialApp(
            child: _BootstrapFailureView(
              result: result,
              onRetry: () => setState(_start),
            ),
          );
        }

        // 关键启动任务已经结束，现在才创建业务 ProviderScope。
        // overrideWithValue 让所有业务 Provider 共享同一份不可变启动结果；
        // 非关键预热会由 MyApp 按“首帧后/会话完成后”分级触发，不延长当前等待时间。
        return ProviderScope(
          // 启动结果由当前 Gate 写入内层 Scope，业务 Provider 可以直接读取。
          // 项目入口若有外层 ProviderScope overrides，这里会自然继承。
          overrides: [bootstrapResultProvider.overrideWithValue(result)],
          child: MyApp(routeBundle: widget.routeBundle),
        );
      },
    );
  }
}

class _BootstrapMaterialApp extends StatelessWidget {
  const _BootstrapMaterialApp({required this.child});

  /// 启动中或启动失败时需要显示的主体内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 业务 MaterialApp 尚未创建，所以启动/失败页面需要一个最小 MaterialApp
    // 提供主题、方向、MaterialLocalizations 等基础环境。
    return MaterialApp(
      title: EnvConfig.appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SafeArea(child: child)),
    );
  }
}

class _BootstrapFailureView extends StatelessWidget {
  const _BootstrapFailureView({required this.result, required this.onRetry});

  /// failed 启动结果，用于提取稳定阶段名；不会直接显示原始异常。
  final BootstrapResult result;

  /// 用户点击重试后的回调；BootstrapGate 会创建新 Future 并重新执行启动流程。
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // 页面只展示稳定的阶段名，不直接展示 error.toString()。原始异常已经保存在
    // BootstrapIssue 并交给 CrashReporter，避免把内部地址或配置细节暴露给用户。
    final stages = result.issues.map((issue) => issue.stage).join('、');
    final strings = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(strings.initializationFailed),
            const SizedBox(height: 8),
            Text(strings.failedStages(stages), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(strings.retry)),
          ],
        ),
      ),
    );
  }
}
