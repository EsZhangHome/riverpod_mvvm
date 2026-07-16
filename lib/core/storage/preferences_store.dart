// 普通、非敏感偏好的稳定访问端口。
//
// Bootstrap 仍通过 LocalStorage 在业务 ProviderScope 创建前准备 SharedPreferences，
// 以支持主题同步恢复；业务层只依赖本接口。这样测试、品牌壳或未来存储迁移可以通过
// Riverpod override 替换实现，不再共享插件静态状态。

import 'local_storage.dart';

/// 非敏感键值偏好的最小读写契约。
///
/// 只保留当前底座真正需要的 String/bool。Token、密码和完整认证会话必须使用
/// SecureStorageService/SessionStore；复杂结构和查询应使用 DatabaseService。
abstract interface class PreferencesStore {
  /// 同步读取字符串；key 不存在或存储处于降级状态时返回 null。
  String? getString(String key);

  /// 写入字符串，true 表示实现确认成功。
  Future<bool> setString(String key, String value);

  /// 同步读取 bool；不存在或降级时返回 [defaultValue]。
  bool getBool(String key, {bool defaultValue = false});

  /// 写入 bool，true 表示实现确认成功。
  Future<bool> setBool(String key, bool value);

  /// 删除单个 key；不提供通用 clear，避免业务误删其他模块偏好。
  Future<bool> remove(String key);
}

/// 读取 Bootstrap 已初始化 LocalStorage 的默认适配器。
///
/// 本类没有可变字段，也不会在构造时触发平台通道。Provider 可以安全创建它；真正
/// SharedPreferences 实例仍由 AppBootstrap 在首屏前初始化一次。
final class BootstrappedPreferencesStore implements PreferencesStore {
  const BootstrappedPreferencesStore();

  @override
  String? getString(String key) => LocalStorage.getString(key);

  @override
  Future<bool> setString(String key, String value) {
    return LocalStorage.setString(key, value);
  }

  @override
  bool getBool(String key, {bool defaultValue = false}) {
    return LocalStorage.getBool(key, defaultValue: defaultValue);
  }

  @override
  Future<bool> setBool(String key, bool value) {
    return LocalStorage.setBool(key, value);
  }

  @override
  Future<bool> remove(String key) => LocalStorage.remove(key);
}
