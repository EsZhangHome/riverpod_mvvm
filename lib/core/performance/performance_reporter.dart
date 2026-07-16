// lib/core/performance/performance_reporter.dart
//
// 性能数据只通过稳定接口上报，底座不绑定 Firebase、Sentry 或公司监控 SDK。

import '../utils/logger.dart';

/// 一条用于聚合耗时的指标。
///
/// 类型系统无法判断 attributes 是否敏感，调用方只能放方法名、阶段名、状态码等
/// 低基数字段，不要放 token、手机号、完整业务对象或可识别用户的动态值。
class PerformanceMetric {
  /// 创建一条不可变性能指标。
  ///
  /// - [name]：稳定的指标名称，如 `app.bootstrap`、`network.request`；不要把 URL id
  ///   拼进名称，否则监控平台会产生大量无法聚合的指标；
  /// - [duration]：本次操作的实际耗时；
  /// - [attributes]：用于分组筛选的低基数字段，如 method/statusCode/environment。
  const PerformanceMetric({
    required this.name,
    required this.duration,
    this.attributes = const {},
  });

  /// 监控平台用于聚合的稳定名称。
  final String name;

  /// 本次样本的耗时，调用方负责选择正确起止边界。
  final Duration duration;

  /// 附加维度；不能含 token、用户输入或无限增长的动态值。
  final Map<String, Object?> attributes;
}

/// 性能平台的最小适配接口。
///
/// 具体实现负责把通用 [PerformanceMetric] 映射到 Firebase、Sentry 或公司 SDK。
abstract interface class PerformanceReporter {
  /// 记录单条 [metric]。实现应尽量快速且不阻塞调用线程。
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

  /// 当前是否配置了真实 Reporter；Noop 实现返回 false。
  static bool get isEnabled => _enabled;

  /// 替换全局性能上报实现。
  ///
  /// [reporter] 通常在 runApplication 的同步配置阶段设置一次；传入
  /// [NoopPerformanceReporter] 会关闭后续记录。不要在每个页面反复 configure，
  /// 否则同一启动周期的指标可能被送到不同后端。
  static void configure(PerformanceReporter reporter) {
    _reporter = reporter;
    _enabled = reporter is! NoopPerformanceReporter;
  }

  /// 记录一个已经测量完成的耗时样本。
  ///
  /// - [name]：稳定指标名；
  /// - [duration]：实际耗时；
  /// - [attributes]：低基数、非敏感维度。
  ///
  /// 未启用时直接返回；Reporter 自身异常会被隔离并降级为警告日志，不影响主流程。
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

  /// 执行异步 [action] 并自动记录从调用到 Future 完成的总耗时。
  ///
  /// [name]/[attributes] 含义同 [record]。泛型 T 是 action 的业务返回类型，本方法
  /// 会原样返回结果；action 抛异常时也会在 finally 中记录耗时，然后保持原异常继续
  /// 向上抛出，因此测量不会吞掉业务失败。
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
