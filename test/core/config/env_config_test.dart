// test/core/config/env_config_test.dart
//
// 这组测试只关心 EnvConfig 的默认值。
// Charles 抓包能力必须默认关闭，避免普通运行或生产包误走代理。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/config/env_config.dart';

void main() {
  group('EnvConfig', () {
    test('Charles proxy is disabled by default', () {
      expect(EnvConfig.enableCharlesProxy, isFalse);
      expect(EnvConfig.charlesProxyHost, '127.0.0.1');
      expect(EnvConfig.charlesProxyPort, 8888);
      expect(EnvConfig.allowCharlesBadCertificate, isFalse);
    });

    test('privacy consent uses one stable policy version and absolute URL', () {
      expect(EnvConfig.privacyPolicyVersion, isNotEmpty);
      expect(EnvConfig.privacyPolicyDocumentVersion, isNotEmpty);
      expect(Uri.parse(EnvConfig.privacyPolicyUrl).isAbsolute, isTrue);
      expect(EnvConfig.userAgreementDocumentVersion, isNotEmpty);
      expect(Uri.parse(EnvConfig.userAgreementUrl).isAbsolute, isTrue);
    });
  });
}
