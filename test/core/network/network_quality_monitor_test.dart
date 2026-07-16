// NetworkQualityMonitor 单元测试。
//
// 使用非常小的自定义阈值直接喂入请求样本，不启动 Dio、计时器或真实网络，重点验证
// “保守判弱、状态去重、稳定恢复”三条规则。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/network_quality_monitor.dart';

void main() {
  late NetworkQualityMonitor monitor;
  late List<NetworkQualityEvent> events;

  setUp(() {
    monitor = NetworkQualityMonitor(
      slowResponseThreshold: const Duration(milliseconds: 100),
      slowSamplesToPoor: 3,
      fastSamplesToRecover: 2,
    );
    events = [];
    monitor.events.listen(events.add);
  });

  tearDown(() => monitor.dispose());

  test('one slow request does not immediately classify network as poor', () {
    monitor.recordSuccess(const Duration(milliseconds: 120));

    expect(monitor.quality, NetworkQuality.unknown);
    expect(events, isEmpty);
  });

  test('three consecutive slow requests publish one poor event', () {
    for (var index = 0; index < 4; index++) {
      monitor.recordSuccess(const Duration(milliseconds: 100));
    }

    expect(monitor.quality, NetworkQuality.poor);
    expect(events, hasLength(1));
    expect(events.single.quality, NetworkQuality.poor);
    expect(events.single.cause, NetworkQualityCause.slowResponses);
  });

  test('transport failure enters poor immediately but ignores duplicates', () {
    monitor
      ..recordTransportFailure()
      ..recordTransportFailure();

    expect(monitor.quality, NetworkQuality.poor);
    expect(events, hasLength(1));
    expect(events.single.cause, NetworkQualityCause.transportFailure);
  });

  test('poor network needs two fast successes before recovered event', () {
    monitor.recordTransportFailure();
    monitor.recordSuccess(const Duration(milliseconds: 20));

    expect(monitor.quality, NetworkQuality.poor);
    expect(events, hasLength(1));

    monitor.recordSuccess(const Duration(milliseconds: 20));

    expect(monitor.quality, NetworkQuality.good);
    expect(events, hasLength(2));
    expect(events.last.cause, NetworkQualityCause.recovered);
  });

  test('fast success from unknown establishes baseline without UI event', () {
    monitor.recordSuccess(const Duration(milliseconds: 20));

    expect(monitor.quality, NetworkQuality.good);
    expect(events, isEmpty);
  });
}
