import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/storage/local_storage.dart';
import 'package:riverpod_mvvm/core/storage/preferences_store.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalPrivacyConsentRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.init();
    repository = const LocalPrivacyConsentRepository(
      BootstrappedPreferencesStore(),
    );
  });

  test('旧版单字符串记录可以兼容读取', () async {
    await LocalStorage.setString(
      PrivacyConsentStorageKeys.acceptedPolicyVersion,
      'legacy-1',
    );

    final record = repository.readAcceptedPolicyRecord();

    expect(record?.consentVersion, 'legacy-1');
    expect(record?.documentVersion, 'legacy-1');
    expect(record?.userAgreementDocumentVersion, 'legacy-1');
    expect(record?.acceptedAtUtc, isNull);
  });

  test('完整同意记录通过单个 JSON 值保存并可恢复', () async {
    final acceptedAt = DateTime.utc(2026, 7, 17, 8, 30);
    final record = PrivacyConsentRecord(
      consentVersion: 'consent-2',
      documentVersion: 'document-7',
      userAgreementDocumentVersion: 'agreement-3',
      acceptedAtUtc: acceptedAt,
    );

    expect(await repository.saveAcceptedPolicyRecord(record), isTrue);

    final restored = repository.readAcceptedPolicyRecord();
    expect(restored?.consentVersion, 'consent-2');
    expect(restored?.documentVersion, 'document-7');
    expect(restored?.userAgreementDocumentVersion, 'agreement-3');
    expect(restored?.acceptedAtUtc, acceptedAt);
    expect(
      LocalStorage.getString(PrivacyConsentStorageKeys.acceptedPolicyVersion),
      isNull,
    );
  });

  test('新记录损坏时失败关闭，不使用残留旧版本绕过门禁', () async {
    await LocalStorage.setString(
      PrivacyConsentStorageKeys.acceptedRecordV1,
      '{broken-json',
    );
    await LocalStorage.setString(
      PrivacyConsentStorageKeys.acceptedPolicyVersion,
      'legacy-accepted',
    );

    expect(repository.readAcceptedPolicyRecord(), isNull);
  });

  test('撤回先写失败关闭墓碑，残留旧版本也不能重新放行', () async {
    await LocalStorage.setString(
      PrivacyConsentStorageKeys.acceptedPolicyVersion,
      'legacy-accepted',
    );

    expect(await repository.clearAcceptedPolicyVersion(), isTrue);
    expect(repository.readAcceptedPolicyRecord(), isNull);
  });
}
