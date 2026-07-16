// lib/core/database/database_migrations.dart
//
// 作用：集中管理数据库建表和升级逻辑。
//
// 重要原则：
// - App 上线后不要随意删表重建，否则用户本地数据会丢失
// - 每次表结构变化都要提升 currentVersion
// - onUpgrade 中只写“从旧版本升级到新版本”的增量 SQL

import 'package:sqflite/sqflite.dart';

import 'database_tables.dart';

/// 数据库迁移管理。
///
/// sqflite 打开数据库时会根据版本自动调用：
/// - 第一次创建：onCreate
/// - 版本升级：onUpgrade
class DatabaseMigrations {
  const DatabaseMigrations._();

  /// 当前数据库版本。
  ///
  /// 新增表、增加字段、创建索引时都需要把版本号 +1。
  static const int currentVersion = 1;

  /// 首次创建数据库。
  ///
  /// 如果当前版本是 3，这里会依次执行 version 1、2、3 的迁移，
  /// 保证新安装用户能一次性得到完整结构。
  /// [db] 是 sqflite 刚打开的数据库；[version] 是 openDatabase 配置的目标版本。
  static Future<void> onCreate(Database db, int version) async {
    for (var targetVersion = 1; targetVersion <= version; targetVersion++) {
      await _runMigration(db, targetVersion);
    }
  }

  /// 数据库升级。
  ///
  /// 例如用户手机里是 version 1，新包是 version 3，
  /// 这里会执行 version 2 和 version 3 的迁移。
  /// [oldVersion] 来自设备已有文件，[newVersion] 来自 [currentVersion]。
  /// 每一步必须能在事务中连续执行，不能依赖页面或网络状态。
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (
      var targetVersion = oldVersion + 1;
      targetVersion <= newVersion;
      targetVersion++
    ) {
      await _runMigration(db, targetVersion);
    }
  }

  /// 根据目标版本执行对应迁移。
  static Future<void> _runMigration(DatabaseExecutor db, int version) async {
    switch (version) {
      case 1:
        await _createVersion1(db);
        break;
      default:
        // 理论上不会走到这里。
        // 如果忘记给新版本写 migration，打开数据库时会暴露问题。
        throw StateError('Missing database migration for version $version');
    }
  }

  /// version 1：创建通用缓存表。
  static Future<void> _createVersion1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.appCache} (
        ${DatabaseTables.cacheKey} TEXT PRIMARY KEY,
        ${DatabaseTables.cacheValue} TEXT NOT NULL,
        ${DatabaseTables.cacheUpdatedAt} INTEGER NOT NULL
      )
    ''');
  }
}
