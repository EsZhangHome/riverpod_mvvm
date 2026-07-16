// 基础设施插件冒烟测试。
//
// 单元测试会把数据库和安全存储替换成 Fake，这能稳定验证业务规则，却无法发现
// Android 平台通道、SQLite 建表或 Keystore 配置问题。本文件只做极小的真实读写，
// 不访问后端、不依赖账号，并在 finally 中清理测试数据。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:riverpod_mvvm/core/database/app_database.dart';
import 'package:riverpod_mvvm/core/database/database_tables.dart';
import 'package:riverpod_mvvm/core/database/sqlite_database_service.dart';
import 'package:riverpod_mvvm/core/storage/secure_storage_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 当前 CI 使用 Android 模拟器。桌面端不是本底座正式支持的平台，因此本地直接
  // `flutter test integration_test` 时跳过真实插件，避免把桌面权限配置误当移动端失败。
  final supportsStarterPlatform = Platform.isAndroid || Platform.isIOS;

  testWidgets('secure storage performs a real platform-channel round trip', (
    tester,
  ) async {
    if (!supportsStarterPlatform) return;

    final storage = FlutterSecureStorageService();
    final key = 'riverpod_mvvm.integration.secure_storage';
    try {
      await storage.delete(key);
      await storage.write(key, 'round-trip-value');
      expect(await storage.read(key), 'round-trip-value');
      await storage.delete(key);
      expect(await storage.read(key), isNull);
    } finally {
      // 断言中途失败也尽量清理，避免测试值残留到下一次运行。
      await storage.delete(key);
    }
  });

  testWidgets('database migration creates a writable app_cache table', (
    tester,
  ) async {
    if (!supportsStarterPlatform) return;

    final database = SqliteDatabaseService();
    const key = 'riverpod_mvvm.integration.database';
    try {
      await database.delete(
        DatabaseTables.appCache,
        where: '${DatabaseTables.cacheKey} = ?',
        whereArgs: [key],
      );
      await database.insert(DatabaseTables.appCache, {
        DatabaseTables.cacheKey: key,
        DatabaseTables.cacheValue: '{"ok":true}',
        DatabaseTables.cacheUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      }, replaceOnConflict: true);
      final rows = await database.query(
        DatabaseTables.appCache,
        where: '${DatabaseTables.cacheKey} = ?',
        whereArgs: [key],
        limit: 1,
      );
      expect(rows.single[DatabaseTables.cacheValue], '{"ok":true}');
    } finally {
      await database.delete(
        DatabaseTables.appCache,
        where: '${DatabaseTables.cacheKey} = ?',
        whereArgs: [key],
      );
      await AppDatabase.close();
    }
  });
}
