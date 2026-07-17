import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';

const _policy = PrivacyPolicyConfig(
  version: 'consent-2',
  documentVersion: 'privacy-doc-3',
  url: 'https://example.test/privacy',
  userAgreementDocumentVersion: 'agreement-doc-4',
  userAgreementUrl: 'https://example.test/agreement',
);

final class _MemoryRepository implements PrivacyConsentRepository {
  _MemoryRepository({this.record, this.saveSucceeds = true});

  PrivacyConsentRecord? record;
  bool saveSucceeds;

  @override
  PrivacyConsentRecord? readAcceptedPolicyRecord() => record;

  @override
  Future<bool> saveAcceptedPolicyRecord(PrivacyConsentRecord record) async {
    if (!saveSucceeds) return false;
    this.record = record;
    return true;
  }

  @override
  Future<bool> clearAcceptedPolicyVersion() async {
    record = null;
    return true;
  }
}

final class _RecordingSdkAdapter implements PrivacyProtectedSdkAdapter {
  int calls = 0;
  PrivacyConsentProof? proof;
  Completer<void>? blocker;
  Object? error;

  @override
  Future<void> initializeWithConsent(PrivacyConsentProof proof) async {
    calls++;
    this.proof = proof;
    final failure = error;
    if (failure != null) throw failure;
    await blocker?.future;
  }
}

ProviderContainer _container(_MemoryRepository repository) {
  return ProviderContainer(
    overrides: [
      privacyPolicyConfigProvider.overrideWithValue(_policy),
      privacyConsentRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

void main() {
  test('没有同意当前版本时完全不调用 SDK Adapter', () async {
    final repository = _MemoryRepository();
    final container = _container(repository);
    final adapter = _RecordingSdkAdapter();
    final initializer = PrivacyProtectedSdkInitializer(
      readConsentState: () => container.read(privacyConsentProvider),
      adapter: adapter,
    );
    addTearDown(container.dispose);

    expect(await initializer.initializeIfAllowed(), isFalse);
    expect(adapter.calls, 0);
    expect(initializer.isInitialized, isFalse);
  });

  test('同意记录保存失败后仍不能初始化 SDK', () async {
    final repository = _MemoryRepository(saveSucceeds: false);
    final container = _container(repository);
    final adapter = _RecordingSdkAdapter();
    final initializer = PrivacyProtectedSdkInitializer(
      readConsentState: () => container.read(privacyConsentProvider),
      adapter: adapter,
    );
    addTearDown(container.dispose);

    final accepted = await container
        .read(privacyConsentProvider.notifier)
        .acceptCurrentPolicy();

    expect(accepted, isFalse);
    expect(await initializer.initializeIfAllowed(), isFalse);
    expect(adapter.calls, 0);
  });

  test('旧政策版本不能生成当前版本授权凭据', () async {
    final repository = _MemoryRepository(
      record: PrivacyConsentRecord.fromLegacyVersion('consent-1'),
    );
    final container = _container(repository);
    final adapter = _RecordingSdkAdapter();
    final initializer = PrivacyProtectedSdkInitializer(
      readConsentState: () => container.read(privacyConsentProvider),
      adapter: adapter,
    );
    addTearDown(container.dispose);

    expect(await initializer.initializeIfAllowed(), isFalse);
    expect(adapter.calls, 0);
  });

  test('当前版本只初始化一次并把完整授权凭据交给 Adapter', () async {
    final acceptedAt = DateTime.utc(2026, 7, 17, 8, 30);
    final repository = _MemoryRepository(
      record: PrivacyConsentRecord(
        consentVersion: _policy.version,
        documentVersion: _policy.documentVersion,
        userAgreementDocumentVersion: _policy.userAgreementDocumentVersion,
        acceptedAtUtc: acceptedAt,
      ),
    );
    final container = _container(repository);
    final adapter = _RecordingSdkAdapter()..blocker = Completer<void>();
    final initializer = PrivacyProtectedSdkInitializer(
      readConsentState: () => container.read(privacyConsentProvider),
      adapter: adapter,
    );
    addTearDown(container.dispose);

    final first = initializer.initializeIfAllowed();
    final second = initializer.initializeIfAllowed();
    expect(adapter.calls, 1);
    adapter.blocker!.complete();

    expect(await Future.wait([first, second]), [true, true]);
    expect(await initializer.initializeIfAllowed(), isTrue);
    expect(adapter.calls, 1);
    expect(adapter.proof?.consentVersion, _policy.version);
    expect(adapter.proof?.privacyDocumentVersion, _policy.documentVersion);
    expect(
      adapter.proof?.userAgreementDocumentVersion,
      _policy.userAgreementDocumentVersion,
    );
    expect(adapter.proof?.acceptedAtUtc, acceptedAt);

    await container.read(privacyConsentProvider.notifier).revoke();
    expect(await initializer.initializeIfAllowed(), isFalse);
    expect(adapter.calls, 1);
  });

  test('Adapter 初始化失败不会标记成功，修复后允许重试', () async {
    final repository = _MemoryRepository(
      record: PrivacyConsentRecord.fromLegacyVersion(_policy.version),
    );
    final container = _container(repository);
    final adapter = _RecordingSdkAdapter()..error = StateError('native failed');
    final initializer = PrivacyProtectedSdkInitializer(
      readConsentState: () => container.read(privacyConsentProvider),
      adapter: adapter,
    );
    addTearDown(container.dispose);

    await expectLater(initializer.initializeIfAllowed(), throwsStateError);
    expect(initializer.isInitialized, isFalse);

    adapter.error = null;
    expect(await initializer.initializeIfAllowed(), isTrue);
    expect(adapter.calls, 2);
  });
}
