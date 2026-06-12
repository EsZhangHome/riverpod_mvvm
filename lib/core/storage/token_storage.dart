// lib/core/storage/token_storage.dart
//
// 作用：专门管理 token 的安全存储，使用系统级安全存储能力。
//
// 架构职责：
// - 隔离 token 的存储 key，避免 'auth_token' 字符串散落在业务代码中
// - 使用 flutter_secure_storage 提供系统级安全存储
// - 提供 getToken/saveToken/clearToken 三个简洁方法
//
// 为什么 token 需要单独存储：
// 1. token 是敏感数据，SharedPreferences 是明文存储，不够安全
// 2. flutter_secure_storage 在 Android 上使用 Keystore，iOS 上使用 Keychain
// 3. 即使 App 数据被备份，安全存储中的数据也不会被导出
// 4. 单独的 TokenStorage 类职责单一，方便替换安全存储实现
//
// 与 LocalStorage 的分工：
// - TokenStorage：存储敏感数据（token），使用系统安全存储
// - LocalStorage：存储普通数据（用户偏好、主题设置等），使用 SharedPreferences

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token 安全存储管理器。
///
/// 使用 flutter_secure_storage 在系统安全区域存储 token，
/// 比 SharedPreferences 更适合保存鉴权凭证。
///
/// 使用方式：
/// ```dart
/// // 登录成功后保存 token
/// await TokenStorage.saveToken('eyJhbGciOi...');
///
/// // App 启动时恢复 token
/// final token = await TokenStorage.getToken();
///
/// // 退出登录时清除 token
/// await TokenStorage.clearToken();
/// ```
class TokenStorage {
  TokenStorage._();

  /// token 在安全存储中的 key。
  /// 不直接暴露，避免外部误用。
  static const String _tokenKey = 'auth_token';

  /// flutter_secure_storage 实例。
  ///
  /// Android：使用 EncryptedSharedPreferences 或 Android Keystore
  /// iOS：使用 Keychain
  /// 数据在 App 卸载后会清除（iOS 可能保留，取决于 Keychain 配置）
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// 获取已保存的 token。
  ///
  /// 返回 null 表示未登录或 token 已被清除。
  ///
  /// 注意：安全存储的读取是异步的，调用方需要 await。
  /// AuthProvider.restoreSession 在 App 启动时 await 这个方法。
  static Future<String?> getToken() {
    return _storage.read(key: _tokenKey);
  }

  /// 保存 token。
  ///
  /// 通常在登录成功后调用，把 token 持久化到安全存储中。
  ///
  /// [token]：JWT 或其他格式的鉴权令牌。
  static Future<void> saveToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  /// 清除 token。
  ///
  /// 通常在退出登录时调用，确保下次启动 App 不会恢复旧的登录态。
  static Future<void> clearToken() {
    return _storage.delete(key: _tokenKey);
  }
}
