import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/errors/storage_exception.dart';
import 'package:riverpod_mvvm/core/storage/secure_storage_service.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/features/auth/repository/session_store.dart';

void main() {
  const session = AuthSession(
    token: 'token',
    user: UserModel(id: '1', name: 'User', email: 'user@example.com'),
  );

  test('writes and restores one versioned session value', () async {
    final storage = _MemorySecureStorage();
    final store = SecureSessionStore(storage);

    await store.write(session);
    final restored = await store.read();

    expect(storage.values.keys, contains('auth_session_v1'));
    expect(restored?.token, session.token);
    expect(restored?.user, session.user);
  });

  test('migrates complete legacy values and removes old keys', () async {
    final storage = _MemorySecureStorage()..values['auth_token'] = 'old-token';
    var legacyUser = '{"id":"1","name":"Old User","email":"old@example.com"}';
    final store = SecureSessionStore(
      storage,
      readLegacyUserJson: () => legacyUser,
      clearLegacyUser: () async => legacyUser = '',
    );

    final restored = await store.read();

    expect(restored?.token, 'old-token');
    expect(restored?.user.name, 'Old User');
    expect(storage.values['auth_session_v1'], isNotEmpty);
    expect(storage.values['auth_token'], isNull);
    expect(legacyUser, isEmpty);
  });

  test(
    'incomplete legacy values are cleared instead of partially restored',
    () async {
      final storage = _MemorySecureStorage()
        ..values['auth_token'] = 'old-token';
      final store = SecureSessionStore(storage, readLegacyUserJson: () => null);

      final restored = await store.read();

      expect(restored, isNull);
      expect(storage.values['auth_token'], isNull);
    },
  );

  test('corrupted persisted session becomes a typed storage failure', () async {
    final storage = _MemorySecureStorage()
      ..values['auth_session_v1'] = '{invalid-json';
    final store = SecureSessionStore(storage);

    await expectLater(
      store.read(),
      throwsA(
        isA<StorageException>().having(
          (error) => error.cause,
          'original cause',
          isA<FormatException>(),
        ),
      ),
    );
  });
}

final class _MemorySecureStorage implements SecureStorageService {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
