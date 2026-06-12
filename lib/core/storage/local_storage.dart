// lib/core/storage/local_storage.dart
//
// 作用：SharedPreferences 的薄封装，提供安全的本地键值存储读写。
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
// 4. 未来如果替换存储实现（如换成 Hive），只需要修改这个类
//
// 与 TokenStorage 的区别：
// - LocalStorage：普通键值存储，适合用户偏好、主题设置等
// - TokenStorage：专门存储敏感数据（token），使用系统安全存储

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/crash_reporter.dart';

/// SharedPreferences 的薄封装。
///
/// 业务层统一使用 LocalStorage 而不是直接操作 SharedPreferences，
/// 方便以后替换存储实现（如从 SharedPreferences 换成 Hive 或 MMKV）。
///
/// 使用方式：
/// ```dart
/// // 初始化（在 main.dart 中调用一次）
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
  /// 在 App 启动时调用一次（main.dart 中），后续读写不需要重复 await getInstance。
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
  /// 返回 null 的情况：
  /// - 尚未初始化
  /// - key 不存在
  /// - 值不是 String 类型
  static String? getString(String key) {
    if (!_initialized) {
      // 未初始化时返回 null，让调用方按"没有缓存"处理
      return null;
    }
    return _preferences?.getString(key);
  }

  /// 写入字符串值。
  ///
  /// 返回 true 表示写入成功，false 表示写入失败（未初始化或存储异常）。
  static Future<bool> setString(String key, String value) {
    if (!_initialized) {
      // 写入失败用 false 表达，不抛异常影响业务流程
      return Future<bool>.value(false);
    }
    return _preferences!.setString(key, value);
  }

  /// 读取布尔值。
  ///
  /// [defaultValue]：key 不存在或未初始化时返回的默认值。
  /// 支持默认值可以避免调用方每次都判空。
  static bool getBool(String key, {bool defaultValue = false}) {
    if (!_initialized) {
      return defaultValue;
    }
    return _preferences?.getBool(key) ?? defaultValue;
  }

  /// 写入布尔值。
  ///
  /// 返回 true 表示写入成功，false 表示写入失败。
  static Future<bool> setBool(String key, bool value) {
    if (!_initialized) {
      return Future<bool>.value(false);
    }
    return _preferences!.setBool(key, value);
  }

  /// 删除指定 key 的值。
  ///
  /// 返回 true 表示删除成功，false 表示删除失败。
  static Future<bool> remove(String key) {
    if (!_initialized) {
      return Future<bool>.value(false);
    }
    return _preferences!.remove(key);
  }

  /// 清空所有存储数据。
  ///
  /// 注意：这是高风险操作，会删除所有 SharedPreferences 数据。
  /// 通常只在退出登录或清除缓存时使用。
  ///
  /// 返回 true 表示清空成功，false 表示清空失败。
  static Future<bool> clear() {
    if (!_initialized) {
      // clear 是高风险操作，未初始化时直接返回失败
      return Future<bool>.value(false);
    }
    return _preferences!.clear();
  }
}
