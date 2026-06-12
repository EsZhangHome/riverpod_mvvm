// test/core/database/database_tables_test.dart
//
// 数据库表名和字段名是全项目共享常量。
// 这里用测试锁住基础表结构，避免后续改名导致缓存读写失效。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/database/database_migrations.dart';
import 'package:riverpod_mvvm/core/database/database_tables.dart';

void main() {
  group('DatabaseTables', () {
    test('app cache table keeps stable names', () {
      expect(DatabaseMigrations.currentVersion, 1);
      expect(DatabaseTables.appCache, 'app_cache');
      expect(DatabaseTables.cacheKey, 'cache_key');
      expect(DatabaseTables.cacheValue, 'cache_value');
      expect(DatabaseTables.cacheUpdatedAt, 'updated_at');
    });
  });
}
