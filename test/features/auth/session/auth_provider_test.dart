// AuthNotifier 会话测试。
//
// 测试通过 Riverpod override 注入内存 SessionStore，不访问设备的
// Keychain/Keystore。这样既能验证 ViewModel 的状态流转，也不会把插件实现细节
// 混入 ViewModel 单元测试。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';

final class _MemorySessionStore implements SessionStore {
  _MemorySessionStore([this.session]);

  AuthSession? session;
  Object? readError;
  Object? writeError;
  Object? clearError;
  var clearCount = 0;

  @override
  Future<AuthSession?> read() async {
    if (readError case final error?) throw error;
    return session;
  }

  @override
  Future<void> write(AuthSession value) async {
    if (writeError case final error?) throw error;
    session = value;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    if (clearError case final error?) throw error;
    session = null;
  }
}

final class _PendingSessionRefresher implements SessionRefresher {
  final Completer<String?> result = Completer<String?>();

  @override
  Future<String?> refreshAccessToken() => result.future;
}

final class _PendingReadSessionStore implements SessionStore {
  final Completer<void> readStarted = Completer<void>();
  final Completer<AuthSession?> readResult = Completer<AuthSession?>();

  AuthSession? session;
  var clearCount = 0;

  @override
  Future<AuthSession?> read() {
    if (!readStarted.isCompleted) readStarted.complete();
    return readResult.future;
  }

  @override
  Future<void> write(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    session = null;
  }
}

Future<AuthState> _waitForRestoration(ProviderContainer container) async {
  // build() 用 microtask 启动恢复；轮询只负责等待测试同步点。
  for (var attempt = 0; attempt < 100; attempt++) {
    final state = container.read(authProvider);
    if (!state.isRestoringSession) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('AuthNotifier did not finish session restoration');
}

ProviderContainer _containerWith(_MemorySessionStore store) {
  return ProviderContainer(
    overrides: [sessionStoreProvider.overrideWithValue(store)],
  );
}

void main() {
  const savedSession = AuthSession(
    token: 'saved_token',
    user: UserModel(id: '1', name: 'Saved User', email: 'saved@example.com'),
  );

  test('restores one complete session from secure storage boundary', () async {
    final store = _MemorySessionStore(savedSession);
    final container = _containerWith(store);
    addTearDown(container.dispose);

    final state = await _waitForRestoration(container);

    expect(state.status, AuthStatus.authenticated);
    expect(state.session, savedSession);
  });

  test(
    'activateSession persists session before publishing logged-in state',
    () async {
      final store = _MemorySessionStore();
      final container = _containerWith(store);
      addTearDown(container.dispose);
      await _waitForRestoration(container);
      const user = UserModel(
        id: '2',
        name: 'New User',
        email: 'new@example.com',
      );

      final persisted = await container
          .read(authProvider.notifier)
          .activateSession(AuthSession(token: 'new_token', user: user));

      expect(persisted, isTrue);
      expect(store.session?.token, 'new_token');
      expect(store.session?.user, user);
      expect(container.read(authProvider).currentUser, user);
    },
  );

  test('storage failure keeps user logged out', () async {
    final store = _MemorySessionStore()..writeError = StateError('disk full');
    final container = _containerWith(store);
    addTearDown(container.dispose);
    await _waitForRestoration(container);
    const user = UserModel(id: '2', name: 'New User', email: 'new@example.com');

    final persisted = await container
        .read(authProvider.notifier)
        .activateSession(AuthSession(token: 'new_token', user: user));

    expect(persisted, isFalse);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  test('logout clears memory state and persisted session', () async {
    final store = _MemorySessionStore(savedSession);
    final container = _containerWith(store);
    addTearDown(container.dispose);
    await _waitForRestoration(container);

    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    expect(store.session, isNull);
    expect(store.clearCount, 1);
  });

  test('logout invalidates an in-flight token refresh', () async {
    final store = _MemorySessionStore(savedSession);
    final refresher = _PendingSessionRefresher();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        sessionRefresherProvider.overrideWithValue(refresher),
      ],
    );
    addTearDown(container.dispose);
    await _waitForRestoration(container);

    final refresh = container.read(authProvider.notifier).refreshAccessToken();
    await container.read(authProvider.notifier).logout();
    refresher.result.complete('late_refreshed_token');

    expect(await refresh, isNull);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    expect(store.session, isNull);
    expect(store.clearCount, 1);
  });

  test('failed startup restore cannot overwrite a newer login', () async {
    final store = _PendingReadSessionStore();
    final container = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    // 读取 authProvider 会创建 Notifier；等待 readStarted 可确保启动恢复已经占用存储
    // 队列，再模拟用户通过新的认证流程建立会话。
    container.read(authProvider);
    await store.readStarted.future;
    final activation = container
        .read(authProvider.notifier)
        .activateSession(savedSession);
    store.readResult.completeError(const FormatException('broken old data'));

    expect(await activation, isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authProvider).session, savedSession);
    expect(store.session, savedSession);
    expect(store.clearCount, 0);
  });

  test(
    'strict logout reports persistent clear failure after one retry',
    () async {
      final store = _MemorySessionStore(savedSession)
        ..clearError = StateError('keychain unavailable');
      final container = _containerWith(store);
      addTearDown(container.dispose);
      await _waitForRestoration(container);

      await expectLater(
        container
            .read(authProvider.notifier)
            .logout(requirePersistentClear: true),
        throwsA(isA<StateError>()),
      );

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(store.session, savedSession);
      expect(store.clearCount, 2);
    },
  );

  test(
    'invalid persisted session is cleared instead of partially restored',
    () async {
      final store = _MemorySessionStore()..readError = const FormatException();
      final container = _containerWith(store);
      addTearDown(container.dispose);

      final state = await _waitForRestoration(container);

      expect(state.status, AuthStatus.unauthenticated);
      expect(store.clearCount, 1);
    },
  );
}
