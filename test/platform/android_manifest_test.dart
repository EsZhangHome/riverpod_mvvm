import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main manifest grants network access to release builds', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.INTERNET'),
      reason: 'Release does not merge debug/profile manifests.',
    );
  });
}
