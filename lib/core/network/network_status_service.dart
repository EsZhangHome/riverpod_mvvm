// lib/core/network/network_status_service.dart
//
// 作用：统一封装网络连接状态。
//
// 业务代码不要直接依赖 connectivity_plus。
// 通过 NetworkStatusService 可以让 Repository / ViewModel 只关心“是否有网络”，
// 后续替换实现或写 fake 测试都更方便。

import 'package:connectivity_plus/connectivity_plus.dart';

/// 当前网络连接类型。
///
/// none 表示当前设备没有可用网络连接。
/// 注意：有连接不等于一定能访问互联网，接口是否可访问仍然以真实请求结果为准。
enum NetworkConnectionType {
  wifi,
  mobile,
  ethernet,
  bluetooth,
  satellite,
  vpn,
  other,
  none,
}

/// 网络状态数据。
class NetworkStatus {
  const NetworkStatus(this.type);

  /// 当前网络连接类型。
  final NetworkConnectionType type;

  /// 是否有网络连接。
  bool get isConnected => type != NetworkConnectionType.none;
}

/// 网络状态服务抽象。
abstract class NetworkStatusService {
  /// 获取当前网络状态。
  Future<NetworkStatus> getCurrentStatus();

  /// 监听网络状态变化。
  Stream<NetworkStatus> watchStatus();
}

/// 基于 connectivity_plus 的网络状态实现。
class ConnectivityNetworkStatusService implements NetworkStatusService {
  ConnectivityNetworkStatusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetworkStatus> getCurrentStatus() async {
    final result = await _connectivity.checkConnectivity();
    return mapConnectivityResult(result);
  }

  @override
  Stream<NetworkStatus> watchStatus() {
    return _connectivity.onConnectivityChanged.map(mapConnectivityResult);
  }

  /// 把三方库的 ConnectivityResult 列表转成项目自己的 NetworkStatus。
  ///
  /// 单独抽出这个方法，方便单元测试，也避免业务层依赖三方库枚举。
  static NetworkStatus mapConnectivityResult(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return const NetworkStatus(NetworkConnectionType.none);
    }

    if (results.contains(ConnectivityResult.mobile)) {
      return const NetworkStatus(NetworkConnectionType.mobile);
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return const NetworkStatus(NetworkConnectionType.wifi);
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return const NetworkStatus(NetworkConnectionType.ethernet);
    }
    if (results.contains(ConnectivityResult.vpn)) {
      return const NetworkStatus(NetworkConnectionType.vpn);
    }
    if (results.contains(ConnectivityResult.bluetooth)) {
      return const NetworkStatus(NetworkConnectionType.bluetooth);
    }
    if (results.contains(ConnectivityResult.satellite)) {
      return const NetworkStatus(NetworkConnectionType.satellite);
    }
    if (results.contains(ConnectivityResult.other)) {
      return const NetworkStatus(NetworkConnectionType.other);
    }

    return const NetworkStatus(NetworkConnectionType.other);
  }
}
