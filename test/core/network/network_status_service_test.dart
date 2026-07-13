// test/core/network/network_status_service_test.dart
//
// 只测试项目自己的状态映射，不测试 connectivity_plus 插件本身。

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/network/network_status_service.dart';

void main() {
  group('ConnectivityNetworkStatusService', () {
    test('maps wifi to connected status', () {
      final status = ConnectivityNetworkStatusService.mapConnectivityResult(
        const [ConnectivityResult.wifi],
      );

      expect(status.type, NetworkConnectionType.wifi);
      expect(status.isConnected, isTrue);
    });

    test('maps none to disconnected status', () {
      final status = ConnectivityNetworkStatusService.mapConnectivityResult(
        const [ConnectivityResult.none],
      );

      expect(status.type, NetworkConnectionType.none);
      expect(status.isConnected, isFalse);
    });

    test('maps multiple connectivity results using plugin priority order', () {
      // 插件可能同时报告多种连接；项目用固定优先级得到唯一业务状态。
      final status = ConnectivityNetworkStatusService.mapConnectivityResult(
        const [ConnectivityResult.wifi, ConnectivityResult.mobile],
      );

      expect(status.type, NetworkConnectionType.mobile);
      expect(status.isConnected, isTrue);
    });

    test('maps satellite to connected status', () {
      final status = ConnectivityNetworkStatusService.mapConnectivityResult(
        const [ConnectivityResult.satellite],
      );

      expect(status.type, NetworkConnectionType.satellite);
      expect(status.isConnected, isTrue);
    });
  });
}
