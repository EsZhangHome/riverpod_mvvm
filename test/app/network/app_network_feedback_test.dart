// AppNetworkFeedback Widget 测试。
//
// Fake Service 与可配置 Monitor 替代平台网络和真实 Dio，请求，验证 App 组合层只把
// 有意义的状态边界转换成公共 Toast，而不是在启动在线时打扰用户。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/network/app_network_feedback.dart';
import 'package:riverpod_mvvm/core/network/network_quality_monitor.dart';
import 'package:riverpod_mvvm/core/network/network_status_service.dart';
import 'package:riverpod_mvvm/core/providers/service_providers.dart';
import 'package:riverpod_mvvm/l10n/app_localizations.dart';

final class _FakeNetworkStatusService implements NetworkStatusService {
  _FakeNetworkStatusService(this.current);

  NetworkStatus current;
  final _changes = StreamController<NetworkStatus>.broadcast(sync: true);

  @override
  Future<NetworkStatus> getCurrentStatus() async => current;

  @override
  Stream<NetworkStatus> watchStatus() => _changes.stream;

  void emit(NetworkConnectionType type) {
    current = NetworkStatus(type);
    _changes.add(current);
  }

  Future<void> dispose() => _changes.close();
}

Widget _buildTestApp({
  required NetworkStatusService networkService,
  required NetworkQualityMonitor qualityMonitor,
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return ProviderScope(
    overrides: [
      networkStatusServiceProvider.overrideWithValue(networkService),
      networkQualityMonitorProvider.overrideWithValue(qualityMonitor),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return AppNetworkFeedback(
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const Scaffold(body: Text('content')),
    ),
  );
}

void main() {
  testWidgets('online startup is silent, disconnect and reconnect show toast', (
    tester,
  ) async {
    final service = _FakeNetworkStatusService(
      const NetworkStatus(NetworkConnectionType.wifi),
    );
    final monitor = NetworkQualityMonitor();
    addTearDown(service.dispose);
    addTearDown(monitor.dispose);

    await tester.pumpWidget(
      _buildTestApp(networkService: service, qualityMonitor: monitor),
    );
    await tester.pump();

    // 首值在线只是建立基线，不应该每次打开 App 都提示“网络已恢复”。
    expect(find.text('网络连接已恢复'), findsNothing);

    service.emit(NetworkConnectionType.none);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('当前网络不可用，请检查网络设置'), findsOneWidget);

    service.emit(NetworkConnectionType.mobile);
    await tester.pump();
    // 新 Toast 会立即替换旧 Overlay，再执行自己的进入动画。
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('网络连接已恢复'), findsOneWidget);
  });

  testWidgets('real transport failure and stable recovery show quality toast', (
    tester,
  ) async {
    final service = _FakeNetworkStatusService(
      const NetworkStatus(NetworkConnectionType.wifi),
    );
    final monitor = NetworkQualityMonitor(
      slowResponseThreshold: const Duration(milliseconds: 100),
      fastSamplesToRecover: 2,
    );
    addTearDown(service.dispose);
    addTearDown(monitor.dispose);

    await tester.pumpWidget(
      _buildTestApp(networkService: service, qualityMonitor: monitor),
    );
    await tester.pump();

    monitor.recordTransportFailure();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('当前网络较慢，正在尝试重新连接'), findsOneWidget);

    monitor
      ..recordSuccess(const Duration(milliseconds: 20))
      ..recordSuccess(const Duration(milliseconds: 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('网络状况已恢复'), findsOneWidget);
  });
}
