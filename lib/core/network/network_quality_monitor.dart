// lib/core/network/network_quality_monitor.dart
//
// 作用：根据 App 已经发出的真实接口请求，判断当前网络是否可能处于弱网。
//
// 为什么不定时请求一个 ping 地址：
// - 会额外消耗流量、电量和服务端资源；
// - ping 成功只代表探测地址可用，不代表真正业务接口可用；
// - App 进入后台后还需要额外处理定时器暂停，复杂度和误报概率都会增加。
//
// 本监控器直接接收 Dio 拦截器产生的“请求耗时”和“传输失败”样本。它不依赖
// Flutter、Riverpod 或 Dio，因此可以独立单元测试，也可以在更换网络库后继续复用。

import 'dart:async';

/// 网络质量等级。
///
/// [unknown] 表示样本还不够，不等于网络有问题；[poor] 只表达“真实请求表现较差”，
/// 不能精确区分运营商、设备信号、网关或服务端处理慢等具体原因。
enum NetworkQuality {
  /// 还没有足够的真实请求样本。
  unknown,

  /// 最近请求表现正常。
  good,

  /// 最近出现连续慢响应或网络层传输失败。
  poor,
}

/// 网络质量发生变化的主要原因。
enum NetworkQualityCause {
  /// 多个真实请求连续超过慢响应阈值。
  slowResponses,

  /// 连接、发送或接收阶段发生超时/连接失败。
  transportFailure,

  /// 弱网后连续出现足够数量的快速成功响应。
  recovered,
}

/// 发给 UI 层的一次网络质量变化事件。
class NetworkQualityEvent {
  /// 创建不可变事件。
  const NetworkQualityEvent({required this.quality, required this.cause});

  /// 变化后的质量等级。
  final NetworkQuality quality;

  /// 触发本次变化的原因。
  final NetworkQualityCause cause;
}

/// 真实请求驱动的轻量弱网监控器。
///
/// 默认策略刻意偏保守：
/// - 单个慢请求可能只是某个接口计算复杂，不立即认定弱网；
/// - 连续 3 个请求都不低于 3 秒，才发布弱网事件；
/// - 连接/收发超时属于更强网络信号，第一次发生就发布弱网事件；
/// - 进入弱网后连续 2 个快速成功请求，才认为质量恢复；
/// - 状态没有变化时不重复发布事件，避免全局 Toast 持续打扰用户。
///
/// 阈值都可以在测试或具体项目 Provider override 中调整。不同业务如果有长轮询、
/// 大文件上传下载等天然耗时请求，应在请求上下文中排除质量统计，而不是盲目调大
/// 全局阈值；底座普通 JSON 请求默认参与统计。
class NetworkQualityMonitor {
  /// 创建网络质量监控器。
  ///
  /// 参数说明：
  /// - [slowResponseThreshold]：单次成功请求达到该耗时后计为一个慢样本；
  /// - [slowSamplesToPoor]：需要多少个连续慢样本才进入 poor；
  /// - [fastSamplesToRecover]：poor 后需要多少个连续快速成功样本才恢复 good。
  NetworkQualityMonitor({
    this.slowResponseThreshold = const Duration(seconds: 3),
    this.slowSamplesToPoor = 3,
    this.fastSamplesToRecover = 2,
  }) {
    if (slowResponseThreshold <= Duration.zero) {
      throw ArgumentError.value(
        slowResponseThreshold,
        'slowResponseThreshold',
        '必须大于 0',
      );
    }
    if (slowSamplesToPoor <= 0) {
      throw ArgumentError.value(
        slowSamplesToPoor,
        'slowSamplesToPoor',
        '必须大于 0',
      );
    }
    if (fastSamplesToRecover <= 0) {
      throw ArgumentError.value(
        fastSamplesToRecover,
        'fastSamplesToRecover',
        '必须大于 0',
      );
    }
  }

  /// 单次成功请求的慢响应判断阈值。
  final Duration slowResponseThreshold;

  /// 连续慢响应多少次后进入弱网。
  final int slowSamplesToPoor;

  /// 弱网后连续快速成功多少次才恢复。
  final int fastSamplesToRecover;

  final _events = StreamController<NetworkQualityEvent>.broadcast(sync: true);

  NetworkQuality _quality = NetworkQuality.unknown;
  int _consecutiveSlowSamples = 0;
  int _consecutiveFastSamples = 0;
  bool _disposed = false;

  /// 当前质量快照。刚创建且没有请求样本时为 unknown。
  NetworkQuality get quality => _quality;

  /// 只在质量真正跨越 good/poor 边界时发出事件。
  Stream<NetworkQualityEvent> get events => _events.stream;

  /// 记录一次成功请求的完整耗时。
  ///
  /// [elapsed] 应从请求真正发出前开始计算，到响应或解析前结束。负数没有意义，
  /// 会被直接忽略。达到阈值使用 `>=`，便于项目用整数秒配置明确边界。
  void recordSuccess(Duration elapsed) {
    if (_disposed || elapsed.isNegative) return;

    if (elapsed >= slowResponseThreshold) {
      _consecutiveSlowSamples++;
      _consecutiveFastSamples = 0;
      if (_consecutiveSlowSamples >= slowSamplesToPoor) {
        _setPoor(NetworkQualityCause.slowResponses);
      }
      return;
    }

    _consecutiveSlowSamples = 0;
    if (_quality != NetworkQuality.poor) {
      // 初次快速成功只建立内部 good 基线，不向 UI 弹“网络已恢复”。
      _quality = NetworkQuality.good;
      return;
    }

    _consecutiveFastSamples++;
    if (_consecutiveFastSamples < fastSamplesToRecover) return;

    _consecutiveFastSamples = 0;
    _quality = NetworkQuality.good;
    _events.add(
      const NetworkQualityEvent(
        quality: NetworkQuality.good,
        cause: NetworkQualityCause.recovered,
      ),
    );
  }

  /// 记录一次明确的网络层传输失败。
  ///
  /// 这里只应接收连接超时、发送超时、接收超时或 connectionError。HTTP 4xx/5xx、
  /// 证书错误、业务错误和用户取消都不能算弱网，否则会把服务端或业务问题误报给用户。
  void recordTransportFailure() {
    if (_disposed) return;
    _consecutiveSlowSamples = 0;
    _consecutiveFastSamples = 0;
    _setPoor(NetworkQualityCause.transportFailure);
  }

  void _setPoor(NetworkQualityCause cause) {
    if (_quality == NetworkQuality.poor) return;
    _quality = NetworkQuality.poor;
    _events.add(
      NetworkQualityEvent(quality: NetworkQuality.poor, cause: cause),
    );
  }

  /// 关闭广播流。由创建本对象的 Riverpod Provider 在容器销毁时调用。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _events.close();
  }
}
