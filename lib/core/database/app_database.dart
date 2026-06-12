// lib/core/database/app_database.dart
//
// 作用：数据库初始化入口，负责打开 SQLite 数据库并执行迁移。
//
// 注意：
// - 业务代码不要直接调用 sqflite.openDatabase
// - Repository 也不要直接依赖 AppDatabase
// - Repository 应该依赖 DatabaseService，这样更方便测试和替换实现

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';

/// App 本地数据库入口。
///
/// main.dart 会在 runApp 前调用 AppDatabase.init()。
/// 如果某些测试或特殊场景没有提前初始化，database getter 也会懒加载打开数据库。
class AppDatabase {
  const AppDatabase._();

  /// 数据库文件名。
  static const String databaseName = 'provider_mvvm.db';

  /// 当前数据库实例。
  static Database? _database;

  /// 初始化数据库。
  ///
  /// 多次调用是安全的：如果数据库已经打开，会直接复用已有实例。
  static Future<void> init() async {
    _database ??= await _openDatabase();
  }

  /// 获取数据库实例。
  ///
  /// 正常情况下 main.dart 已经完成初始化。
  /// 这里保留懒加载，避免测试或特殊入口忘记初始化时直接崩溃。
  static Future<Database> get database async {
    if (_database == null) {
      await init();
    }
    return _database!;
  }

  /// 关闭数据库。
  ///
  /// App 正常运行中一般不需要手动关闭。
  /// 测试或需要释放资源时可以调用。
  static Future<void> close() async {
    final database = _database;
    if (database == null) {
      return;
    }

    await database.close();
    _database = null;
  }

  /// 打开数据库文件并绑定迁移逻辑。
  static Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final databasePath = p.join(databasesPath, databaseName);

    return openDatabase(
      databasePath,
      version: DatabaseMigrations.currentVersion,
      onCreate: DatabaseMigrations.onCreate,
      onUpgrade: DatabaseMigrations.onUpgrade,
    );
  }
}
