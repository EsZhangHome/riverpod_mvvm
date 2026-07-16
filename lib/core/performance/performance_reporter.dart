// lib/core/performance/performance_reporter.dart
//
// 性能数据只通过稳定接口上报，底座不绑定 Firebase、Sentry 或公司监控 SDK。

import '../utils/logger.dart';

/// 一条用于聚合耗时的指标。
///
/// 类型系统无法判断 attributes 是否敏感，调用方只能放方法名、阶段名、状态码等
/// 低基数字段，不要放 token、手机号、完整业务对象或可识别用户的动态值。
class PerformanceMetric {
  const PerformanceMetric({
    required this.name,
    required this.duration,
    this.attributes = const {},
  });

  final String name;
  final Duration duration;
  final Map<String, Object?> attributes;
}

abstract interface class PerformanceReporter {
  void record(PerformanceMetric metric);
}

class NoopPerformanceReporter implements PerformanceReporter {
  const NoopPerformanceReporter();

  @override
  void record(PerformanceMetric metric) {}
}

/// 启动前和 Provider 外部都能使用的轻量性能门面。
abstract final class AppPerformance {
  static PerformanceReporter _reporter = const NoopPerformanceReporter();
  static bool _enabled = false;

  static bool get isEnabled => _enabled;

  static void configure(PerformanceReporter reporter) {
    _reporter = reporter;
    _enabled = reporter is! NoopPerformanceReporter;
  }

  static void record(
    String name,
    Duration duration, {
    Map<String, Object?> attributes = const {},
  }) {
    if (!_enabled) return;
    try {
      // 性能 SDK 是旁路能力。厂商 SDK 自身抛错时，网络请求、启动流程和页面
      // 构建仍要正常继续，因此这里与日志、崩溃上报门面一样隔离 SDK 故障。
      _reporter.record(
        PerformanceMetric(
          name: name,
          duration: duration,
          attributes: Map.unmodifiable(attributes),
        ),
      );
    } on Object catch (error) {
      AppLogger.warning(
        'Performance reporting failed',
        context: {'metric': name, 'errorType': error.runtimeType.toString()},
      );
    }
  }

  static Future<T> measure<T>(
    String name,
    Future<T> Function() action, {
    Map<String, Object?> attributes = const {},
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      record(name, stopwatch.elapsed, attributes: attributes);
    }
  }
}
