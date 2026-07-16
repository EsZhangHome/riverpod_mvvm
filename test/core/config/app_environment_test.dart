import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/config/app_environment.dart';

void main() {
  const safeProduction = EnvironmentConfig(
    environment: AppEnvironment.production,
    appName: 'Enterprise App',
    apiBaseUrl: 'https://api.acme.com',
    privacyPolicyVersion: '2026.07.01',
    privacyPolicyDocumentVersion: '2026.07.01-doc.1',
    privacyPolicyUrl: 'https://www.acme.com/privacy',
    userAgreementDocumentVersion: '2026.07.01-agreement.1',
    userAgreementUrl: 'https://www.acme.com/agreement',
    enableMock: false,
    enableDebugLogs: false,
    enableCharlesProxy: false,
    allowBadCertificate: false,
  );

  test('production safe configuration passes validation', () {
    expect(
      EnvironmentValidator.validate(safeProduction, releaseMode: true),
      isEmpty,
    );
  });

  test('release build rejects unsafe development switches', () {
    const unsafe = EnvironmentConfig(
      environment: AppEnvironment.development,
      appName: 'Enterprise App',
      apiBaseUrl: 'http://api.example.com',
      privacyPolicyVersion: '',
      privacyPolicyDocumentVersion: '',
      privacyPolicyUrl: 'http://privacy.example.com',
      userAgreementDocumentVersion: '',
      userAgreementUrl: 'http://privacy.example.com/agreement',
      enableMock: true,
      enableDebugLogs: true,
      enableCharlesProxy: true,
      allowBadCertificate: true,
    );

    final issues = EnvironmentValidator.validate(unsafe, releaseMode: true);

    expect(issues, contains('正式环境 API 必须使用 HTTPS'));
    expect(issues, contains('ENV_PRIVACY_POLICY_VERSION 不能为空'));
    expect(issues, contains('ENV_PRIVACY_POLICY_DOCUMENT_VERSION 不能为空'));
    expect(issues, contains('ENV_USER_AGREEMENT_DOCUMENT_VERSION 不能为空'));
    expect(issues, contains('正式环境隐私政策必须使用 HTTPS'));
    expect(issues, contains('正式环境不能使用示例隐私政策地址'));
    expect(issues, contains('正式环境用户协议必须使用 HTTPS'));
    expect(issues, contains('正式环境不能使用示例用户协议地址'));
    expect(issues, contains('正式环境必须关闭 Mock'));
    expect(issues, contains('正式环境必须关闭调试日志'));
    expect(issues, contains('正式环境必须关闭抓包代理'));
    expect(issues, contains('正式环境禁止跳过证书校验'));
  });

  test('unknown environment fails early', () {
    expect(
      () => AppEnvironment.parse('preview'),
      throwsA(isA<ConfigurationException>()),
    );
  });
}
