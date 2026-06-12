// lib/core/utils/logger.dart
//
// 作用：简单日志工具，在 debug 模式下打印日志，release 模式下自动静默。
//
// 设计要点：
// 1. 统一日志前缀 [ProviderMVVM]，方便在控制台中过滤和搜索
// 2. 只使用 debugPrint（Flutter 内置），不引入额外依赖
// 3. 只在 debug 模式下打印，release 包不会输出日志
// 4. 后续可以替换为更完整的日志库（如 logger 包），调用方不需要改动
//
// 使用方式：
// ```dart
// AppLogger.log('用户登录成功');
// AppLogger.log('请求失败: $error');
// ```

import 'package:flutter/foundation.dart';

/// 简单日志工具。
///
/// 提供统一的日志输出入口，后续可以替换成更完整的日志库
/// （如 logger 包、或接入远程日志平台），但调用方不用改任何代码。
class AppLogger {
  const AppLogger._();

  /// 打印日志消息。
  ///
  /// [message]：日志内容，可以是字符串或任何有 toString() 的对象。
  ///
  /// 只在 debug 模式下打印，release 模式下自动跳过。
  /// 使用 debugPrint 而不是 print，因为 debugPrint 对长消息有截断保护。
  static void log(Object message) {
    if (kDebugMode) {
      // 统一前缀方便在日志中搜索和过滤
      debugPrint('[ProviderMVVM] $message');
    }
  }
}
