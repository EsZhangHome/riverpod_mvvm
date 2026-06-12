// lib/core/utils/crash_reporter.dart
//
// 作用：全局异常上报入口，统一收集和处理 App 中的异常信息。
//
// 当前阶段只打印日志，后续可以在这里接入 Sentry、Bugly、Firebase Crashlytics 等平台。
//
// 接入方式（以 Sentry 为例）：
// ```dart
// static void report(Object error, StackTrace? stack) {
//   Sentry.captureException(error, stackTrace: stack);
//   AppLogger.log('CrashReporter error: $error');
// }
// ```
//
// 设计要点：
// 1. 全 App 只有一个上报入口，main.dart 中 FlutterError.onError 和 PlatformDispatcher 都走这里
// 2. 当前只打日志，后续接入线上平台只需要改这个类，不影响其他代码
// 3. 上报时可以补充设备信息、用户信息、App 版本号等上下文

import 'logger.dart';

/// 全局异常上报入口。
///
/// 所有异常最终都汇集到这里，统一处理。
/// 当前只打日志，后续接入线上崩溃平台时只需要修改这个类。
class CrashReporter {
  const CrashReporter._();

  /// 上报异常（全局唯一入口）。
  ///
  /// 调用时机：
  /// - FlutterError.onError：Flutter 框架层面的异常
  /// - PlatformDispatcher.instance.onError：Dart 异步 Zone 外的异常
  /// - try-catch 中手动调用：业务层捕获到的异常
  ///
  /// 接入 Sentry 示例：
  /// ```dart
  /// // 1. pubspec.yaml 添加 sentry_flutter
  /// // 2. main.dart 中 SentryFlutter.init(...)
  /// // 3. 修改 report 方法：
  /// static void report(Object error, StackTrace? stack) {
  ///   Sentry.captureException(error, stackTrace: stack);
  ///   AppLogger.log('Crash: $error');
  /// }
  /// ```
  static void report(Object error, StackTrace? stack) {
    AppLogger.log('CrashReporter error: $error');
    if (stack != null) {
      AppLogger.log(stack);
    }
  }
}
