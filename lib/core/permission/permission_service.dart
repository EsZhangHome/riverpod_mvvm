// lib/core/permission/permission_service.dart
//
// 作用：统一封装 App 权限申请。
//
// 页面和 ViewModel 不直接依赖 permission_handler，
// 而是通过 PermissionService 申请权限，方便统一弹窗文案、统一测试、统一替换实现。

import 'package:permission_handler/permission_handler.dart' as handler;

/// App 内部关心的权限类型。
///
/// 这里只列中型业务 App 常见权限。后续需要蓝牙、通讯录等权限时，再按需增加。
enum AppPermissionType {
  camera,
  photos,
  microphone,
  locationWhenInUse,
  notification,
  storage,
}

/// App 内部统一的权限状态。
enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  provisional,
}

/// 权限请求结果。
class AppPermissionResult {
  const AppPermissionResult({required this.type, required this.status});

  /// 权限类型。
  final AppPermissionType type;

  /// 当前权限状态。
  final AppPermissionStatus status;

  /// 是否可以继续执行业务逻辑。
  ///
  /// limited 是 iOS 相册常见状态，表示用户只授权了一部分照片，也可以继续使用。
  bool get isGranted =>
      status == AppPermissionStatus.granted ||
      status == AppPermissionStatus.limited;

  /// 是否需要引导用户去系统设置页。
  bool get shouldOpenSettings =>
      status == AppPermissionStatus.permanentlyDenied;
}

/// 权限服务抽象。
abstract class PermissionService {
  /// 查询权限状态，不弹系统授权框。
  Future<AppPermissionResult> check(AppPermissionType type);

  /// 请求权限，可能弹系统授权框。
  Future<AppPermissionResult> request(AppPermissionType type);

  /// 打开系统设置页。
  Future<bool> openSettings();
}

/// 基于 permission_handler 的权限实现。
class PermissionHandlerService implements PermissionService {
  @override
  Future<AppPermissionResult> check(AppPermissionType type) async {
    final permission = mapPermissionType(type);
    final status = await permission.status;
    return AppPermissionResult(type: type, status: mapPermissionStatus(status));
  }

  @override
  Future<AppPermissionResult> request(AppPermissionType type) async {
    final permission = mapPermissionType(type);
    final status = await permission.request();
    return AppPermissionResult(type: type, status: mapPermissionStatus(status));
  }

  @override
  Future<bool> openSettings() {
    return handler.openAppSettings();
  }

  /// 把项目权限类型映射到 permission_handler 权限类型。
  static handler.Permission mapPermissionType(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return handler.Permission.camera;
      case AppPermissionType.photos:
        return handler.Permission.photos;
      case AppPermissionType.microphone:
        return handler.Permission.microphone;
      case AppPermissionType.locationWhenInUse:
        return handler.Permission.locationWhenInUse;
      case AppPermissionType.notification:
        return handler.Permission.notification;
      case AppPermissionType.storage:
        return handler.Permission.storage;
    }
  }

  /// 把三方库权限状态映射成项目内部状态。
  static AppPermissionStatus mapPermissionStatus(
    handler.PermissionStatus status,
  ) {
    if (status.isGranted) {
      return AppPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return AppPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return AppPermissionStatus.restricted;
    }
    if (status.isLimited) {
      return AppPermissionStatus.limited;
    }
    if (status.isProvisional) {
      return AppPermissionStatus.provisional;
    }
    return AppPermissionStatus.denied;
  }
}
