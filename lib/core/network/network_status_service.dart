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
  /// Wi-Fi 网络。
  wifi,

  /// 蜂窝移动网络。
  mobile,

  /// 有线以太网。
  ethernet,

  /// 蓝牙网络共享。
  bluetooth,

  /// 卫星网络。
  satellite,

  /// VPN 连接。
  vpn,

  /// 插件识别到连接，但底座没有更具体分类。
  other,

  /// 当前没有任何连接。
  none,
}

/// 网络状态数据。
class NetworkStatus {
  /// 创建网络状态快照；[type] 是当前选定的主要连接类型。
  const NetworkStatus(this.type);

  /// 当前网络连接类型。
  final NetworkConnectionType type;

  /// 是否有网络连接。
  bool get isConnected => type != NetworkConnectionType.none;
}

/// 网络状态服务抽象。
abstract class NetworkStatusService {
  /// 主动查询一次当前网络状态。平台通道失败时 Future 会抛错。
  Future<NetworkStatus> getCurrentStatus();

  /// 监听系统连接类型变化。调用方取消 Stream 订阅后应释放插件监听。
  /// 本 Stream 不保证立即发出当前值，需要首值时先调用 [getCurrentStatus]。
  Stream<NetworkStatus> watchStatus();
}

/// 基于 connectivity_plus 的网络状态实现。
class ConnectivityNetworkStatusService implements NetworkStatusService {
  /// 创建 connectivity_plus 适配器。
  /// [connectivity] 为空时创建真实插件实例；测试可注入 Mock/Fake。
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
  /// [results] 可能同时包含多个连接，本实现按 mobile → wifi → ethernet → vpn →
  /// bluetooth → satellite → other 的固定优先级选择一个主要类型；只要包含 none
  /// 就按无连接处理。
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
