// lib/core/storage/local_storage.dart
//
// 作用：SharedPreferences 的薄封装，提供普通偏好的容错读写。
//
// 架构职责：
// - 封装 SharedPreferences 的初始化逻辑
// - 提供类型安全的读写方法（getString/setString/getBool/setBool/remove/clear）
// - 在未初始化时提供安全降级（返回默认值或 false，不抛异常）
// - 集中管理初始化状态，避免业务层重复调用 getInstance
//
// 设计要点：
// 1. 静态方法 + 静态字段，全局只有一个 SharedPreferences 实例
// 2. 初始化失败不阻断 App 启动，所有读写方法做安全降级
// 3. 所有方法都检查 _initialized 状态，防止未初始化时崩溃
// 4. 若新存储仍能提供相同的同步读取与异步写入契约，替换工作主要收敛在本类；
//    如果读写模型不同，还需同步调整 Bootstrap 和调用方接口
//
// 与 SessionStore 的区别：
// - LocalStorage：普通键值存储，适合主题、开关等非敏感偏好；
// - SessionStore：保存 token 和用户信息组成的完整会话，使用系统安全存储。
// 敏感信息不要写入本类，否则可能以明文形式出现在设备备份或应用数据中。

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/crash_reporter.dart';

/// SharedPreferences 的薄封装。
///
/// 业务层统一使用 LocalStorage 而不是直接操作 SharedPreferences，可以减少以后
/// 更换实现时的改动范围；但 Hive 等异步模型不同的方案仍可能需要调整本类契约。
///
/// 使用方式：
/// ```dart
/// // 初始化（由 AppBootstrap 在业务 ProviderScope 创建前调用一次）
/// await LocalStorage.init();
///
/// // 读写操作
/// await LocalStorage.setString('theme', 'dark');
/// final theme = LocalStorage.getString('theme');
/// ```
class LocalStorage {
  LocalStorage._();

  /// SharedPreferences 单例，初始化后缓存。
  /// 为 null 表示初始化失败或尚未初始化。
  static SharedPreferences? _preferences;

  /// 初始化状态标记。
  /// true 表示已成功初始化，可以正常读写。
  static bool _initialized = false;

  /// 是否已成功初始化。
  static bool get isInitialized => _initialized;

  /// 初始化 SharedPreferences。
  ///
  /// 在 AppBootstrap 创建业务 ProviderScope 前调用一次，后续读写不需要重复
  /// `await SharedPreferences.getInstance()`。
  ///
  /// 初始化失败时的处理：
  /// - 记录错误到 CrashReporter
  /// - 设置 _initialized = false
  /// - 后续所有读写方法会安全降级（返回 null 或 false）
  /// - 不会阻断 App 启动
  static Future<void> init() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      _initialized = true;
    } catch (error, stack) {
      // 本地存储失败不应该阻断 App 启动
      // 记录错误后，所有读写方法都会走安全降级逻辑
      _initialized = false;
      CrashReporter.report(error, stack);
    }
  }

  /// 读取字符串值。
  ///
  /// [key] 是稳定存储键，应由拥有该偏好的模块集中声明常量；不要使用用户输入作为
  /// key，也不要与其他模块复用含义不同的同名 key。
  ///
  /// 返回 null 的情况：
  /// - 尚未初始化
  /// - key 不存在
  ///
  /// SharedPreferences 要求同一个 key 始终使用相同类型。如果其他代码曾用同名 key
  /// 写入非 String 值，插件读取时可能抛出类型异常，而不是把协议错误伪装成“没有值”。
  static String? getString(String key) {
    if (!_initialized) {
      // 未初始化时返回 null，让调用方按"没有缓存"处理
      return null;
    }
    return _preferences?.getString(key);
  }

  /// 写入字符串值。
  ///
  /// [key] 是存储键；[value] 是普通非敏感字符串。token、密码、身份证号等敏感
  /// 数据必须使用 SessionStore/SecureStorage，而不是本方法。
  ///
  /// 返回 true 表示插件写入成功；未初始化时返回 false。
  /// 插件执行期间的异常会通过 Future 继续抛出，由调用方按业务重要性处理。
  static Future<bool> setString(String key, String value) {
    if (!_initialized) {
      // 这里只处理“尚未初始化”；真正插件写入异常不会在此静默吞掉。
      return Future<bool>.value(false);
    }
    return _preferences!.setString(key, value);
  }

  /// 读取布尔值。
  ///
  /// [key] 是稳定存储键；[defaultValue] 是 key 不存在或未初始化时的业务默认值。
  /// 支持默认值可以避免调用方每次都判空。
  /// 如果同名 key 实际保存的不是 bool，插件读取时可能抛出类型异常。
  static bool getBool(String key, {bool defaultValue = false}) {
    if (!_initialized) {
      return defaultValue;
    }
    return _preferences?.getBool(key) ?? defaultValue;
  }

  /// 写入布尔值。
  ///
  /// [key] 和 [value] 分别是稳定键与布尔值；本方法不会自动加模块前缀。
  /// 返回 true 表示插件写入成功，未初始化时返回 false；插件异常继续抛出。
  static Future<bool> setBool(String key, bool value) {
    if (!_initialized) {
      return Future<bool>.value(false);
    }
    return _preferences!.setBool(key, value);
  }

  /// 删除指定 key 的值。
  ///
  /// [key] 只删除这一项，不影响其他模块偏好。适合清理废弃字段或用户级普通配置。
  /// 返回 true 表示插件删除成功，未初始化时返回 false；插件异常继续抛出。
  static Future<bool> remove(String key) {
    if (!_initialized) {
      return Future<bool>.value(false);
    }
    return _preferences!.remove(key);
  }

  /// 清空所有存储数据。
  ///
  /// 注意：这是高风险操作，会删除所有 SharedPreferences 数据，包括主题等
  /// 与账号无关的偏好。普通退出登录应只删除用户级 key，不应调用本方法。
  ///
  /// 返回 true 表示插件清空成功，未初始化时返回 false；插件异常继续抛出。
  static Future<bool> clear() {
    if (!_initialized) {
      // clear 是高风险操作，未初始化时直接返回失败
      return Future<bool>.value(false);
    }
    return _preferences!.clear();
  }
}
