// lib/core/storage/secure_storage_service.dart
//
// 敏感数据存储抽象。业务模块只依赖本接口，不直接创建 FlutterSecureStorage，
// 因此测试可以注入内存实现，未来也能替换企业密钥 SDK。

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 系统安全存储提供的最小能力。
abstract interface class SecureStorageService {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// 基于 Keychain / Android 安全存储的生产实现。
class FlutterSecureStorageService implements SecureStorageService {
  FlutterSecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
