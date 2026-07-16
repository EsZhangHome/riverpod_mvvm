// lib/core/storage/secure_storage_service.dart
//
// 敏感数据存储抽象。业务模块只依赖本接口，不直接创建 FlutterSecureStorage，
// 因此测试可以注入内存实现，未来也能替换企业密钥 SDK。

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 系统安全存储提供的最小能力。
abstract interface class SecureStorageService {
  /// 读取 [key] 对应的敏感字符串；不存在时返回 null。
  /// 平台通道、解密或 Keychain/Keystore 异常会继续抛出。
  Future<String?> read(String key);

  /// 把 [value] 写入 [key]。同 key 写入通常覆盖旧值；是否需要先序列化完整对象由
  /// 上层 SessionStore/Repository 决定。本接口不记录日志，避免泄露敏感内容。
  Future<void> write(String key, String value);

  /// 删除 [key]；key 不存在时由底层插件按其幂等语义处理。
  Future<void> delete(String key);
}

/// 基于 Keychain / Android 安全存储的生产实现。
class FlutterSecureStorageService implements SecureStorageService {
  /// 创建系统安全存储适配器。
  ///
  /// [storage] 为空时使用 flutter_secure_storage 默认配置；项目需要 access group、
  /// Android 加密选项或测试 Fake 时可注入预先配置的实例。具体平台能力和备份策略
  /// 仍需按项目安全规范配置，不能因为类名含 Secure 就忽略威胁模型。
  FlutterSecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// 真正的平台插件实例，只在本适配器内部使用。
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
