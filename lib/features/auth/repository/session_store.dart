// lib/features/auth/repository/session_store.dart
//
// AuthNotifier 只表达“读、写、清理完整会话”，不关心 Keychain、Keystore 或 key。

import 'dart:convert';

import '../../../core/storage/secure_storage_service.dart';
import '../model/auth_session.dart';
import '../model/user_model.dart';

typedef LegacyUserJsonReader = String? Function();
typedef LegacyUserClearer = Future<void> Function();

/// 登录会话持久化端口。
abstract interface class SessionStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

/// 把一个完整会话序列化到单个安全存储 key。
class SecureSessionStore implements SessionStore {
  const SecureSessionStore(
    this._storage, {
    LegacyUserJsonReader? readLegacyUserJson,
    LegacyUserClearer? clearLegacyUser,
    // Public named parameters intentionally map to private implementation fields.
    // ignore: prefer_initializing_formals
  }) : _readLegacyUserJson = readLegacyUserJson,
       // ignore: prefer_initializing_formals
       _clearLegacyUser = clearLegacyUser;

  static const _sessionKey = 'auth_session_v1';
  static const _legacyTokenKey = 'auth_token';
  final SecureStorageService _storage;
  final LegacyUserJsonReader? _readLegacyUserJson;
  final LegacyUserClearer? _clearLegacyUser;

  @override
  Future<AuthSession?> read() async {
    final value = await _storage.read(_sessionKey);
    if (value != null && value.isNotEmpty) {
      final json = jsonDecode(value);
      if (json is! Map) throw const FormatException('Invalid auth session');
      return AuthSession.fromJson(Map<String, dynamic>.from(json));
    }

    // 旧版本把 token 与用户 JSON 分开存储。这里仅做一次兼容迁移：两部分都完整
    // 才组成新会话，先写入新 key，再删除旧数据，避免升级后无故退出或长期残留
    // 旧 token。全新项目没有旧数据时不会产生额外写入。
    final legacyToken = await _storage.read(_legacyTokenKey);
    final legacyUserJson = _readLegacyUserJson?.call();
    if (legacyToken == null ||
        legacyToken.isEmpty ||
        legacyUserJson == null ||
        legacyUserJson.isEmpty) {
      await _clearLegacy();
      return null;
    }
    final legacyUser = jsonDecode(legacyUserJson);
    if (legacyUser is! Map) {
      await _clearLegacy();
      throw const FormatException('Invalid legacy auth user');
    }
    final session = AuthSession(
      token: legacyToken,
      user: UserModel.fromJson(Map<String, dynamic>.from(legacyUser)),
    );
    await write(session);
    await _clearLegacy();
    return session;
  }

  @override
  Future<void> write(AuthSession session) {
    return _storage.write(_sessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    // 退出时同时清理旧 key，确保从早期版本升级的设备不残留有效凭据。
    await Future.wait([_storage.delete(_sessionKey), _clearLegacy()]);
  }

  Future<void> _clearLegacy() async {
    await Future.wait([
      _storage.delete(_legacyTokenKey),
      if (_clearLegacyUser != null) _clearLegacyUser(),
    ]);
  }
}
