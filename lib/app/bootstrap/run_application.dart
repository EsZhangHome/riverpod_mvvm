// lib/app/bootstrap/run_application.dart
//
// 应用统一启动函数。把日志、全局异常和 BootstrapGate 集中在这里，
// 避免不同品牌壳或测试入口复制一套稍后容易失去同步的启动代码。

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/config/env_config.dart';
import '../../core/performance/performance_reporter.dart';
import '../../core/utils/crash_reporter.dart';
import '../../core/utils/logger.dart';
import '../navigation/app_route_bundle.dart';
import 'bootstrap_gate.dart';

/// 给具体项目包装根 Widget 的组合函数。
///
/// 最常见用法是返回带 overrides 的 ProviderScope。这里使用 Widget 回调而不是把
/// Riverpod 3 的内部 Override 类型暴露在公共函数签名中，升级 Riverpod 时更稳定。
typedef AppRootBuilder = Widget Function(Widget child);

/// 启动应用，并把入口选择的 [routeBundle] 交给后续路由组合。
///
/// 这个函数只做“runApp 前必须完成”的同步工作：绑定 Flutter Engine、配置日志、
/// 安装全局异常入口。任何可以晚一点做的 SDK 初始化都不应在这里 `await`，否则
/// 用户会一直看到原生启动图，却不知道应用正在做什么。
///
/// [rootBuilder] 是项目组合入口：正式项目可用 ProviderScope 包装 child，替换响应
/// 协议、Token 刷新、监控预热任务或测试依赖，不必修改底座内部 Provider。
///
/// 参数说明：
/// - [routeBundle]：必填，描述登录后首页、登录页、业务路由和受保护路径；
/// - [rootBuilder]：可选，在 BootstrapGate 外包装根 Widget，主要用于创建外层
///   ProviderScope 并提供项目级 overrides；回调必须把收到的 child 放回 Widget 树；
/// - [logSink]：可选的结构化日志输出端；为空时使用仅 Debug 输出的 DebugLogSink；
/// - [crashReportingBackend]：可选崩溃平台适配器；这里只完成注入，耗时 initialize
///   仍由首帧后的 AppWarmup 调用；
/// - [performanceReporter]：可选性能上报实现；提供后才注册帧、网络、启动等指标。
///
/// 返回的 Future 只表示同步启动编排已经执行到 runApp。它不会等待 Bootstrap、
/// 登录态恢复、Warmup 或首页网络请求完成。
Future<void> runApplication(
  AppRouteBundle routeBundle, {
  AppRootBuilder? rootBuilder,
  LogSink? logSink,
  CrashReportingBackend? crashReportingBackend,
  PerformanceReporter? performanceReporter,
}) async {
  // 插件和平台通道在使用前必须绑定 Flutter Engine。
  WidgetsFlutterBinding.ensureInitialized();

  // Logger 先于其他初始化配置，后面的启动失败才有统一记录出口。
  AppLogger.configure(
    logSink ??
        DebugLogSink(prefix: EnvConfig.appName, enabled: EnvConfig.isDebug),
    globalContext: {'environment': EnvConfig.environmentName},
  );
  if (crashReportingBackend != null) {
    CrashReporter.configure(crashReportingBackend);
  }
  if (performanceReporter != null) {
    AppPerformance.configure(performanceReporter);
  }

  // FlutterError 捕获 Widget 构建、布局和绘制阶段错误；
  // PlatformDispatcher 捕获未进入 FlutterError 的异步 Dart 错误。
  FlutterError.onError = _onFlutterError;
  PlatformDispatcher.instance.onError = _onPlatformError;

  if (AppPerformance.isEnabled) {
    WidgetsBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        AppPerformance.record('frame.build', timing.buildDuration);
        AppPerformance.record('frame.raster', timing.rasterDuration);
      }
    });
  }

  // runApp 后立刻有可绘制的启动界面。BootstrapGate 只等待环境校验和
  // LocalStorage；监控在首帧后预热，SQLite 在第一次 CRUD 时按需打开。
  final application = BootstrapGate(routeBundle: routeBundle);
  // ProviderScope 即使现在被创建，Provider 仍然是惰性的。真正读取主题和登录态
  // 发生在 BootstrapGate 完成关键任务、创建 MyApp 之后，因此不会提前访问存储。
  runApp(rootBuilder?.call(application) ?? application);
}

void _onFlutterError(FlutterErrorDetails details) {
  // Debug 时仍保留 Flutter 默认红屏/控制台输出，同时上报统一监控入口。
  FlutterError.presentError(details);
  CrashReporter.report(details.exception, details.stack, fatal: true);
}

bool _onPlatformError(Object error, StackTrace stack) {
  CrashReporter.report(error, stack, fatal: true);
  // 返回 true 表示错误已经被统一处理，避免运行时再次视为未处理异常。
  return true;
}
