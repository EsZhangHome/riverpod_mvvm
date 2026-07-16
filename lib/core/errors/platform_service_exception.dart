// 权限、网络状态、包信息等平台插件的稳定异常边界。

import 'app_failure.dart';

/// 非存储类平台服务调用失败。
///
/// 此类错误通常表示平台通道、插件注册或系统 API 异常，不能误提示成“用户拒绝权限”
/// 或“设备已离线”，因此归到 unknown 并进入非致命监控。页面只显示安全兜底文案。
class PlatformServiceException extends AppFailure {
  const PlatformServiceException({
    required String service,
    required String operation,
    super.cause,
    super.stackTrace,
  }) : super(
         kind: FailureKind.unknown,
         debugMessage: '$service failed while $operation',
       );
}
