// lib/main.dart
//
// 作用：App 的入口文件，负责初始化顺序和全局异常捕获。
//
// 迁移说明（Provider → Riverpod）：
// - 移除 setupServiceLocator() 调用（get_it 不再使用）
// - runApp 外包裹 ProviderScope（Riverpod 的根节点）
//
// 启动流程：
// 1. 注册全局异常捕获
// 2. 绑定 Flutter 引擎
// 3. 初始化本地存储
// 4. 初始化本地数据库
// 5. 启动 App（ProviderScope → MyApp）

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/storage/local_storage.dart';
import 'core/utils/crash_reporter.dart';

/// App 入口函数。
Future<void> main() async {
  // ==================== 步骤 1：注册全局异常捕获 ====================

  FlutterError.onError = _onFlutterError;
  PlatformDispatcher.instance.onError = _onPlatformError;

  // ==================== 步骤 2：绑定 Flutter 引擎 ====================

  WidgetsFlutterBinding.ensureInitialized();

  // ==================== 步骤 3：初始化本地存储 ====================

  try {
    await LocalStorage.init();
  } catch (error, stack) {
    CrashReporter.report(error, stack);
  }

  // ==================== 步骤 4：初始化本地数据库 ====================

  try {
    await AppDatabase.init();
  } catch (error, stack) {
    CrashReporter.report(error, stack);
  }

  // ==================== 步骤 5：启动 App ====================

  // ProviderScope 是 Riverpod 的根节点，替代了 Provider 的 MultiProvider
  // 和 get_it 的 service_locator。所有 Provider 在此之下可用。
  runApp(const ProviderScope(child: MyApp()));
}

void _onFlutterError(FlutterErrorDetails details) {
  FlutterError.presentError(details);
  CrashReporter.report(details.exception, details.stack);
}

bool _onPlatformError(Object error, StackTrace stack) {
  CrashReporter.report(error, stack);
  return true;
}
