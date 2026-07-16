// lib/features/auth/repository/session_store.dart
//
// AuthNotifier 只表达“读、写、清理完整会话”，不关心 Keychain、Keystore 或 key。

import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/storage_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../model/auth_session.dart';
import '../model/user_model.dart';

typedef LegacyUserJsonReader = String? Function();
typedef LegacyUserClearer = Future<void> Function();

/// 登录会话持久化端口。
abstract interface class SessionStore {
  /// 读取完整会话；没有已保存会话时返回 null，数据损坏时允许抛解析异常。
  Future<AuthSession?> read();

  /// 原子保存 [session]。完成前 AuthNotifier 不会把内存状态切成已登录。
  Future<void> write(AuthSession session);

  /// 删除全部认证凭据。重复调用必须安全，目标状态始终是“本地无会话”。
  Future<void> clear();
}

/// 把一个完整会话序列化到单个安全存储 key。
class SecureSessionStore implements SessionStore {
  /// 创建安全会话存储实现。
  ///
  /// 参数说明：
  /// - [_storage]：Keychain/Keystore 的抽象适配器，负责真正的安全读写；
  /// - [readLegacyUserJson]：可选旧版用户 JSON 读取函数，仅用于从早期普通存储迁移；
  /// - [clearLegacyUser]：可选旧版用户数据清理函数，迁移成功、数据残缺或退出时调用。
  ///
  /// 新项目可以只传 `_storage`。两个 legacy 参数不能用于新业务数据，它们只是保证
  /// 已安装旧版本的设备平滑升级，未来确认不再支持旧版本后可连同迁移代码删除。
  const SecureSessionStore(
    this._storage, {
    LegacyUserJsonReader? readLegacyUserJson,
    LegacyUserClearer? clearLegacyUser,
    // Public named parameters intentionally map to private implementation fields.
    // ignore: prefer_initializing_formals
  }) : _readLegacyUserJson = readLegacyUserJson,
       // ignore: prefer_initializing_formals
       _clearLegacyUser = clearLegacyUser;

  /// 当前完整会话使用的安全存储 key；后缀 v1 对应 AuthSession JSON 协议版本。
  static const _sessionKey = 'auth_session_v1';

  /// 旧版本只保存 token 时使用的 key，仅为一次性兼容迁移保留。
  static const _legacyTokenKey = 'auth_token';

  /// 平台安全存储端口。
  final SecureStorageService _storage;

  /// 旧版普通存储读取回调；null 表示项目没有需要迁移的旧用户数据。
  final LegacyUserJsonReader? _readLegacyUserJson;

  /// 旧版普通存储删除回调；null 表示无需额外清理。
  final LegacyUserClearer? _clearLegacyUser;

  /// 优先读取新版完整会话；不存在时再尝试一次旧格式迁移。
  ///
  /// 返回 null 只表示没有可恢复会话。JSON 格式损坏会抛异常，由 AuthNotifier 上报并
  /// 清理，避免把数据损坏悄悄伪装成正常退出而失去诊断线索。
  @override
  Future<AuthSession?> read() {
    return _guard('Stored auth session read failed', _read);
  }

  /// 真正的恢复与旧数据迁移流程；公开方法只负责建立统一异常边界。
  Future<AuthSession?> _read() async {
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

  /// 将 token 与 user 编码成同一个 JSON 字符串后写入单一安全 key。
  @override
  Future<void> write(AuthSession session) {
    return _guard(
      'Stored auth session write failed',
      () => _storage.write(_sessionKey, jsonEncode(session.toJson())),
    );
  }

  /// 同时删除当前完整会话与旧版残留凭据。
  @override
  Future<void> clear() {
    return _guard('Stored auth session clear failed', () async {
      // 退出时同时清理旧 key，确保从早期版本升级的设备不残留有效凭据。
      await Future.wait([_storage.delete(_sessionKey), _clearLegacy()]);
    });
  }

  Future<void> _clearLegacy() async {
    await Future.wait([
      _storage.delete(_legacyTokenKey),
      if (_clearLegacyUser != null) _clearLegacyUser(),
    ]);
  }

  /// 认证模块自己的 Fake 也可能抛普通异常，因此在 SessionStore 公共出口再守一次。
  /// 已经由安全存储转换过的 AppFailure 原样上抛，避免重复包装；JSON 损坏、旧迁移
  /// 回调或测试实现的异常统一归为 storage，并保留最初 cause/stack。
  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw StorageException(message, cause: error, stackTrace: stackTrace);
    }
  }
}
