import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/app/app_info_service.dart';
import 'package:riverpod_mvvm/core/network/network_status_service.dart';
import 'package:riverpod_mvvm/core/providers/services.dart';
import 'package:riverpod_mvvm/features/mine/view_model/mine_view_model.dart';

class _FakeAppInfoService implements AppInfoService {
  @override
  Future<AppInfo> getAppInfo() async {
    return const AppInfo(
      appName: 'Test App',
      packageName: 'com.example.test',
      version: '2.0.0',
      buildNumber: '8',
    );
  }
}

class _FakeNetworkStatusService implements NetworkStatusService {
  @override
  Future<NetworkStatus> getCurrentStatus() async {
    return const NetworkStatus(NetworkConnectionType.wifi);
  }

  @override
  Stream<NetworkStatus> watchStatus() {
    // 当前值由 getCurrentStatus 提供，后续事件再模拟移动网络。
    return Stream.value(const NetworkStatus(NetworkConnectionType.mobile));
  }
}

void main() {
  test('FutureProvider reads an overridden service', () async {
    // Arrange：只替换 AppInfo Service，其余 Provider 组装保持生产路径。
    final container = ProviderContainer(
      overrides: [
        appInfoServiceProvider.overrideWith((ref) => _FakeAppInfoService()),
      ],
    );
    addTearDown(container.dispose);

    // Act + Assert：读取 .future 等待 AsyncValue 首个 data。
    final info = await container.read(appInfoProvider.future);
    expect(info.displayVersion, '2.0.0+8');
  });

  test('StreamProvider maps an overridden plugin service', () async {
    // Arrange：用 Fake Stream 隔离真实平台网络插件。
    final container = ProviderContainer(
      overrides: [
        networkStatusServiceProvider.overrideWith(
          (ref) => _FakeNetworkStatusService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // listen 保持 autoDispose StreamProvider 存活，等价于页面 ref.watch。
    final subscription = container.listen(networkStatusProvider, (_, _) {});
    addTearDown(subscription.close);

    // StreamProvider.future 返回首个事件，此处应是 getCurrentStatus 的 Wi-Fi。
    final first = await container.read(networkStatusProvider.future);
    expect(first.type, NetworkConnectionType.wifi);
  });
}

// 全局服务 Provider 测试：不启动 package_info_plus/connectivity_plus，使用 override
// 验证页面 Provider 只依赖抽象 Service，并正确转换为 Future/Stream AsyncValue。
