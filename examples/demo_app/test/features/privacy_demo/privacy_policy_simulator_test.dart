import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';
import 'package:riverpod_mvvm_demo/features/privacy_demo/privacy_demo.dart';

final class _MemoryPrivacyConsentRepository
    implements PrivacyConsentRepository {
  _MemoryPrivacyConsentRepository(this.record);

  PrivacyConsentRecord? record;

  @override
  PrivacyConsentRecord? readAcceptedPolicyRecord() => record;

  @override
  Future<bool> saveAcceptedPolicyRecord(PrivacyConsentRecord record) async {
    this.record = record;
    return true;
  }

  @override
  Future<bool> clearAcceptedPolicyVersion() async {
    record = null;
    return true;
  }
}

void main() {
  test('simulated version change enters the real policy-upgrade state', () {
    final repository = _MemoryPrivacyConsentRepository(
      PrivacyConsentRecord.fromLegacyVersion('starter-1'),
    );
    final container = ProviderContainer(
      overrides: [
        privacyConsentRepositoryProvider.overrideWithValue(repository),
        privacyPolicyConfigProvider.overrideWith(
          (ref) => ref.watch(demoPrivacyPolicyConfigProvider),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(privacyConsentProvider).status,
      PrivacyConsentStatus.granted,
    );

    container
        .read(demoPrivacyPolicyConfigProvider.notifier)
        .simulateNextUpgrade();

    final upgraded = container.read(privacyConsentProvider);
    expect(upgraded.status, PrivacyConsentStatus.policyUpgradeRequired);
    expect(upgraded.acceptedVersion, 'starter-1');
    expect(upgraded.policy.version, 'starter-1-demo-upgrade-1');
  });

  test('an accepted Demo version is restored without a duplicate upgrade', () {
    final repository = _MemoryPrivacyConsentRepository(
      PrivacyConsentRecord(
        consentVersion: 'starter-1-demo-upgrade-2',
        documentVersion: 'starter-document-1-demo-upgrade-2',
        userAgreementDocumentVersion: 'starter-user-agreement-1-demo-upgrade-2',
        acceptedAtUtc: DateTime.utc(2026, 7, 18),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        privacyConsentRepositoryProvider.overrideWithValue(repository),
        privacyPolicyConfigProvider.overrideWith(
          (ref) => ref.watch(demoPrivacyPolicyConfigProvider),
        ),
      ],
    );
    addTearDown(container.dispose);

    final restored = container.read(privacyConsentProvider);
    expect(restored.status, PrivacyConsentStatus.granted);
    expect(restored.policy.version, 'starter-1-demo-upgrade-2');

    container
        .read(demoPrivacyPolicyConfigProvider.notifier)
        .simulateNextUpgrade();
    expect(
      container.read(privacyConsentProvider).policy.version,
      'starter-1-demo-upgrade-3',
    );
  });
}
