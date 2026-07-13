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
    return Stream.value(const NetworkStatus(NetworkConnectionType.mobile));
  }
}

void main() {
  test('FutureProvider reads an overridden service', () async {
    final container = ProviderContainer(
      overrides: [
        appInfoServiceProvider.overrideWith((ref) => _FakeAppInfoService()),
      ],
    );
    addTearDown(container.dispose);

    final info = await container.read(appInfoProvider.future);
    expect(info.displayVersion, '2.0.0+8');
  });

  test('StreamProvider maps an overridden plugin service', () async {
    final container = ProviderContainer(
      overrides: [
        networkStatusServiceProvider.overrideWith(
          (ref) => _FakeNetworkStatusService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(networkStatusProvider, (_, _) {});
    addTearDown(subscription.close);

    final first = await container.read(networkStatusProvider.future);
    expect(first.type, NetworkConnectionType.wifi);
  });
}
