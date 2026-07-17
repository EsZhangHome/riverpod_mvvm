import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/privacy/privacy_audit.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('privacy_audit_test_');
    _createMinimalProject(project);
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('检测实际代码中的 Android ID 调用', () async {
    File(
      p.join(project.path, 'lib', 'device_reader.dart'),
    ).writeAsStringSync('final key = Settings.Secure.ANDROID_ID;\n');

    final result = await PrivacyAuditor(_options(project)).run();

    expect(
      result.findings,
      contains(
        isA<AuditFinding>()
            .having((finding) => finding.ruleId, 'ruleId', 'android_id')
            .having(
              (finding) => finding.severity,
              'severity',
              AuditSeverity.blocker,
            ),
      ),
    );
  });

  test('注释中的敏感 API 名称不会误报', () async {
    File(p.join(project.path, 'lib', 'device_reader.dart')).writeAsStringSync(
      '''
// 不允许使用 Settings.Secure.ANDROID_ID
/*
教学说明中也可能写 Settings.Secure.ANDROID_ID，不能当成真实调用。
*/
''',
    );

    final result = await PrivacyAuditor(_options(project)).run();

    expect(
      result.findings.where((finding) => finding.ruleId == 'android_id'),
      isEmpty,
    );
  });

  test('Android 主清单新增未登记权限会阻断', () async {
    File(
      p.join(
        project.path,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    ).writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.CAMERA" />
  <application android:usesCleartextTraffic="false" android:allowBackup="false" />
</manifest>
''');

    final result = await PrivacyAuditor(_options(project)).run();

    expect(
      result.findings,
      contains(
        isA<AuditFinding>()
            .having(
              (finding) => finding.ruleId,
              'ruleId',
              'undeclared_android_permission',
            )
            .having(
              (finding) => finding.severity,
              'severity',
              AuditSeverity.blocker,
            ),
      ),
    );
  });

  test('未登记的 Android 原生插件会阻断', () async {
    File(
      p.join(project.path, '.flutter-plugins-dependencies'),
    ).writeAsStringSync(
      jsonEncode(<String, Object>{
        'plugins': <String, Object>{
          'android': <Object>[
            <String, Object>{
              'name': 'unknown_sdk',
              'path': p.join(project.path, 'unknown_sdk-1.0.0'),
              'dev_dependency': false,
            },
          ],
        },
      }),
    );

    final result = await PrivacyAuditor(_options(project)).run();

    expect(
      result.findings,
      contains(
        isA<AuditFinding>().having(
          (finding) => finding.ruleId,
          'ruleId',
          'undeclared_native_plugin',
        ),
      ),
    );
  });

  test('合并清单中的完整 MainActivity 名称匹配点号简写白名单', () async {
    File(
      p.join(
        project.path,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    ).writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:usesCleartextTraffic="false" android:allowBackup="false">
    <activity
      android:name="com.example.enterprise.MainActivity"
      android:exported="true" />
  </application>
</manifest>
''');

    final result = await PrivacyAuditor(_options(project)).run();

    expect(
      result.findings.where(
        (finding) => finding.ruleId == 'undeclared_exported_component',
      ),
      isEmpty,
    );
  });

  test('Release 审计未指定实际构建环境文件时会阻断', () async {
    final result = await PrivacyAuditor(
      _options(project, mode: AuditMode.release),
    ).run();

    expect(
      result.findings,
      contains(
        isA<AuditFinding>().having(
          (finding) => finding.ruleId,
          'ruleId',
          'release_environment_file_missing',
        ),
      ),
    );
  });

  test('动态脚本旧版同意 key 与配置不一致时会阻断', () async {
    final hook = File(
      p.join(project.path, 'tool', 'privacy', 'android_privacy_hooks.js'),
    );
    hook.writeAsStringSync(
      hook.readAsStringSync().replaceFirst(
        "legacyAcceptedVersionKey: 'flutter.privacy_policy_accepted_version'",
        "legacyAcceptedVersionKey: 'flutter.wrong_legacy_key'",
      ),
    );

    final result = await PrivacyAuditor(_options(project)).run();

    expect(
      result.findings,
      contains(
        isA<AuditFinding>()
            .having(
              (finding) => finding.ruleId,
              'ruleId',
              'dynamic_privacy_hook_config_mismatch',
            )
            .having(
              (finding) => finding.evidence,
              'evidence',
              'legacyAcceptedVersionKey',
            ),
      ),
    );
  });
}

PrivacyAuditOptions _options(
  Directory project, {
  AuditMode mode = AuditMode.development,
}) {
  return PrivacyAuditOptions(
    rootDirectory: project,
    mode: mode,
    configPath: p.join('compliance', 'privacy_audit.json'),
    markdownReportPath: p.join('build', 'privacy.md'),
    jsonReportPath: p.join('build', 'privacy.json'),
    failOn: AuditSeverity.blocker,
  );
}

void _createMinimalProject(Directory project) {
  Directory(p.join(project.path, 'lib')).createSync(recursive: true);
  File(p.join(project.path, 'lib', 'markers.dart')).writeAsStringSync('''
class PrivacyGate {}
void deleteAccount() {}
''');

  final manifest = File(
    p.join(
      project.path,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  manifest.parent.createSync(recursive: true);
  manifest.writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET" />
  <application android:usesCleartextTraffic="false" android:allowBackup="false" />
</manifest>
''');

  File(p.join(project.path, '.flutter-plugins-dependencies')).writeAsStringSync(
    jsonEncode(<String, Object>{
      'plugins': <String, Object>{'android': <Object>[]},
    }),
  );

  final hook = File(
    p.join(project.path, 'tool', 'privacy', 'android_privacy_hooks.js'),
  );
  hook.parent.createSync(recursive: true);
  hook.writeAsStringSync('''
preferencesFile: 'FlutterSharedPreferences'
acceptedVersionKey: 'flutter.privacy_consent_record_v1'
legacyAcceptedVersionKey: 'flutter.privacy_policy_accepted_version'
currentPolicyVersion: 'test-1'
''');

  final config = File(p.join(project.path, 'compliance', 'privacy_audit.json'));
  config.parent.createSync(recursive: true);
  config.writeAsStringSync(
    jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'sourceRoots': <String>['lib', 'android/app/src/main'],
      'allowedPermissions': <Object>[
        <String, String>{
          'name': 'android.permission.INTERNET',
          'purpose': '测试联网',
        },
      ],
      'forbiddenPermissions': <String>[],
      'allowedExportedComponents': <Object>[
        <String, String>{
          'name': '.MainActivity',
          'purpose': '测试 Launcher',
          'requiredPermission': '',
        },
      ],
      'allowedDomains': <Object>[],
      'sensitiveApis': <Object>[
        <String, Object>{
          'id': 'android_id',
          'name': 'Android ID',
          'severity': 'blocker',
          'patterns': <String>['Settings.Secure.ANDROID_ID'],
          'remediation': '删除测试调用',
        },
      ],
      'approvedFindings': <Object>[],
      'nativePlugins': <Object>[],
      'releaseRequirements': <String, Object>{
        'privacyPolicyUrlEnvironmentKey': 'ENV_PRIVACY_POLICY_URL',
        'privacyPolicyVersionEnvironmentKey': 'ENV_PRIVACY_POLICY_VERSION',
        'privacyPolicyDocumentVersionEnvironmentKey':
            'ENV_PRIVACY_POLICY_DOCUMENT_VERSION',
        'userAgreementUrlEnvironmentKey': 'ENV_USER_AGREEMENT_URL',
        'userAgreementDocumentVersionEnvironmentKey':
            'ENV_USER_AGREEMENT_DOCUMENT_VERSION',
        'privacyGateMarkers': <String>['PrivacyGate'],
        'accountDeletionMarkers': <String>['deleteAccount'],
      },
      'dynamicAuditConsent': <String, String>{
        'preferencesFile': 'FlutterSharedPreferences',
        'acceptedVersionKey': 'flutter.privacy_consent_record_v1',
        'legacyAcceptedVersionKey': 'flutter.privacy_policy_accepted_version',
        'currentPolicyVersion': 'test-1',
      },
    }),
  );
}
