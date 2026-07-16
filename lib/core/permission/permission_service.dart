// lib/core/permission/permission_service.dart
//
// 作用：统一封装 App 权限申请。
//
// 页面和 ViewModel 不直接依赖 permission_handler，
// 而是通过 PermissionService 申请权限，方便统一弹窗文案、统一测试、统一替换实现。

import 'package:permission_handler/permission_handler.dart' as handler;

import '../errors/app_failure.dart';
import '../errors/platform_service_exception.dart';

/// App 内部关心的权限类型。
///
/// 这里只列中型业务 App 常见权限。后续需要蓝牙、通讯录等权限时，再按需增加。
enum AppPermissionType {
  /// 相机拍照/扫码。
  camera,

  /// 系统相册读取或选择照片。
  photos,

  /// 麦克风录音。
  microphone,

  /// 仅在使用 App 期间访问位置。
  locationWhenInUse,

  /// 系统通知。
  notification,

  /// 旧版 Android 通用外部存储权限；新系统应优先使用媒体分类权限。
  storage,
}

/// App 内部统一的权限状态。
enum AppPermissionStatus {
  /// 用户已经完整授权。
  granted,

  /// 当前拒绝，但系统未来仍可能允许再次询问。
  denied,

  /// 永久拒绝/不再询问，只能引导用户去系统设置修改。
  permanentlyDenied,

  /// 受系统策略、家长控制或企业设备管理限制，App 无法自行请求解除。
  restricted,

  /// 有限授权，例如 iOS 只允许访问用户选中的部分照片。
  limited,

  /// iOS 临时/静默通知授权状态。
  provisional,
}

/// 权限请求结果。
class AppPermissionResult {
  /// 创建一次权限查询或请求的结果。
  ///
  /// [type] 保留本次操作对应的业务权限，方便批量申请时识别；[status] 是映射后的
  /// 平台无关状态，页面无需 import permission_handler。
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
  /// 查询 [type] 当前状态，不弹系统授权框。
  ///
  /// 返回值同时包含 type/status；平台插件故障会转换为 PlatformServiceException，
  /// 它和用户主动拒绝返回的 denied 是两种不同结果。
  Future<AppPermissionResult> check(AppPermissionType type);

  /// 请求 [type]，可能弹系统授权框。
  ///
  /// 应由明确的用户动作触发，不要在 App 启动时批量申请与当前功能无关的权限。
  Future<AppPermissionResult> request(AppPermissionType type);

  /// 打开当前 App 的系统设置页；返回 true 表示系统接受了打开操作。
  ///
  /// 从设置页返回后权限可能已经变化，页面仍需再次调用 [check]，不能把 true 当作
  /// “用户已经授权”。
  Future<bool> openSettings();
}

/// 基于 permission_handler 的权限实现。
class PermissionHandlerService implements PermissionService {
  @override
  Future<AppPermissionResult> check(AppPermissionType type) async {
    return _guard('checking permission status', () async {
      final permission = mapPermissionType(type);
      final status = await permission.status;
      return AppPermissionResult(
        type: type,
        status: mapPermissionStatus(status),
      );
    });
  }

  @override
  Future<AppPermissionResult> request(AppPermissionType type) async {
    return _guard('requesting permission', () async {
      final permission = mapPermissionType(type);
      final status = await permission.request();
      return AppPermissionResult(
        type: type,
        status: mapPermissionStatus(status),
      );
    });
  }

  @override
  Future<bool> openSettings() {
    return _guard('opening application settings', handler.openAppSettings);
  }

  /// 平台插件故障不是权限拒绝，统一包装成可观测的未知基础设施失败。
  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw PlatformServiceException(
        service: 'permission_handler',
        operation: operation,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 把项目权限类型 [type] 映射到 permission_handler 权限类型。
  ///
  /// 新增 AppPermissionType 时编译器会要求补充 switch 分支，防止漏掉平台映射。
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
  ///
  /// [status] 来自 permission_handler；未知/普通拒绝最终统一为 denied。这样业务层
  /// 只依赖稳定的 AppPermissionStatus，不会被三方库枚举变化直接扩散。
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
