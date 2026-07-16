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
import '../performance/performance_reporter.dart';

/// App 本地数据库入口。
///
/// 这里不在 AppBootstrap 中提前打开数据库。
/// databaseServiceProvider 第一次执行 CRUD 时才读取 [database]，因此没有数据库
/// 需求的首屏不会被 SQLite 文件打开和迁移阻塞。
class AppDatabase {
  const AppDatabase._();

  /// 数据库文件名。
  ///
  /// tool/bootstrap.dart 初始化新项目时会同步替换它。已经发布后修改文件名会让
  /// App 打开一份全新数据库，旧数据不会自动迁移，因此不能把“改名”当普通重构。
  static const String databaseName = 'riverpod_mvvm.db';

  /// 当前数据库实例。
  static Database? _database;
  static Future<Database>? _opening;

  /// 初始化数据库。
  ///
  /// 多次调用是安全的：如果数据库已经打开，会直接复用已有实例。
  /// 通常不需要主动调用；databaseServiceProvider 会在第一次 CRUD 时懒加载。
  /// 只有明确要求在某个业务流程前预先完成迁移时才使用本方法。
  static Future<void> init() async {
    await database;
  }

  /// 获取数据库实例。
  ///
  /// 第一次读取时：获取平台数据库目录、打开 [databaseName]、执行版本迁移，并
  /// 记录 `database.open` 性能指标；后续读取复用同一个实例。
  ///
  /// 并发首次读取会共享 [_opening] Future，不会重复打开。打开失败时异常继续抛出，
  /// 同时清除“正在打开”状态，使下一次调用仍可重试。
  static Future<Database> get database async {
    final opened = _database;
    if (opened != null) return opened;

    // 缓存“正在打开”的 Future。多个 Repository 首次并发 CRUD 时等待同一个
    // openDatabase，不会同时打开同一文件或重复执行 migration。
    final active = _opening;
    if (active != null) return active;

    final future = AppPerformance.measure('database.open', _openDatabase);
    _opening = future;
    try {
      final database = await future;
      _database = database;
      return database;
    } finally {
      // 失败也要清理，下一次 invalidate/appDatabaseProvider 后可以真正重试。
      if (identical(_opening, future)) _opening = null;
    }
  }

  /// 关闭数据库。
  ///
  /// App 正常运行中一般不需要手动关闭。
  /// 测试 teardown、切换完全不同数据库或进程级资源释放时可以调用。若数据库仍在
  /// 打开中，本方法会先等待打开完成；打开 Future 自身失败时该异常仍会抛出。
  static Future<void> close() async {
    final database = _database ?? await _opening;
    if (database == null) {
      return;
    }

    await database.close();
    _database = null;
    _opening = null;
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
