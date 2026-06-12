// test/core/permission/permission_service_test.dart
//
// 只测试项目自己的权限状态映射，不触发真实系统权限弹窗。

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import 'package:riverpod_mvvm/core/permission/permission_service.dart';

void main() {
  group('PermissionHandlerService', () {
    test('maps granted permission status', () {
      final status = PermissionHandlerService.mapPermissionStatus(
        handler.PermissionStatus.granted,
      );

      expect(status, AppPermissionStatus.granted);
    });

    test('maps permanently denied permission status', () {
      final status = PermissionHandlerService.mapPermissionStatus(
        handler.PermissionStatus.permanentlyDenied,
      );

      expect(status, AppPermissionStatus.permanentlyDenied);
    });

    test('limited permission is treated as usable', () {
      const result = AppPermissionResult(
        type: AppPermissionType.photos,
        status: AppPermissionStatus.limited,
      );

      expect(result.isGranted, isTrue);
      expect(result.shouldOpenSettings, isFalse);
    });
  });
}
