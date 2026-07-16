import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/config/app_environment.dart';

void main() {
  const safeProduction = EnvironmentConfig(
    environment: AppEnvironment.production,
    appName: 'Enterprise App',
    apiBaseUrl: 'https://api.acme.com',
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
      enableMock: true,
      enableDebugLogs: true,
      enableCharlesProxy: true,
      allowBadCertificate: true,
    );

    final issues = EnvironmentValidator.validate(unsafe, releaseMode: true);

    expect(issues, contains('正式环境 API 必须使用 HTTPS'));
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
