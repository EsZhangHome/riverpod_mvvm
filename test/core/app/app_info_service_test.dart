// test/core/app/app_info_service_test.dart
//
// AppInfo 是纯数据对象，这里锁住版本展示格式。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/app/app_info_service.dart';

void main() {
  test('app info display version combines version and build number', () {
    const appInfo = AppInfo(
      appName: 'Riverpod MVVM',
      packageName: 'com.eszhanghome.riverpod_mvvm',
      version: '1.2.3',
      buildNumber: '45',
    );

    expect(appInfo.displayVersion, '1.2.3+45');
  });
}
