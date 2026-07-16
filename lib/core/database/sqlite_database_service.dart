// lib/core/database/sqlite_database_service.dart
//
// 作用：DatabaseService 的 sqflite 实现。
//
// sqflite 类型只允许出现在 core/database 及基础设施 Provider 组装处。
// 业务 Repository、ViewModel、View 都不应该 import sqflite。

import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'app_database.dart';
import 'database_exception.dart';
import 'database_service.dart';

/// sqflite 数据库服务实现。
///
/// 默认从 AppDatabase 获取数据库实例。
/// 测试时也可以传入自定义 databaseProvider。
class SqliteDatabaseService extends _SqliteExecutorService {
  /// 创建 sqflite 版 DatabaseService。
  ///
  /// [databaseProvider] 是“需要执行 SQL 时怎样异步取得 Database”的函数：
  /// - null：默认读取 AppDatabase.database；
  /// - 测试传入：可以返回 sqflite_common_ffi 的内存 Database；
  /// - Provider 组合层传入：可以延迟读取 appDatabaseProvider.future。
  ///
  /// 这里注入函数而不是立即传 Database，目的是保留懒加载。构造本 Service 不会
  /// 打开文件，第一次 CRUD 获取 executor 时才真正触发数据库初始化。
  SqliteDatabaseService({Future<Database> Function()? databaseProvider})
    : _databaseProvider = databaseProvider ?? (() => AppDatabase.database);

  /// 每次数据库操作获取 executor 的入口。默认函数最终会复用 AppDatabase 单例。
  final Future<Database> Function() _databaseProvider;

  @override
  Future<DatabaseExecutor> get executor => _databaseProvider();
}

/// 基于 DatabaseExecutor 的通用实现。
///
/// sqflite 的 Database 和 Transaction 都实现了 DatabaseExecutor，
/// 所以普通操作和事务操作可以复用同一套 CRUD 代码。
abstract class _SqliteExecutorService implements DatabaseService {
  /// 普通服务返回 Database，事务服务返回 Transaction。
  /// CRUD 只依赖二者共同实现的 DatabaseExecutor。
  Future<DatabaseExecutor> get executor;

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceOnConflict = false,
  }) {
    // 所有公开操作统一进入 _guard，保证三方异常不会越过数据层边界。
    return _guard('插入数据失败', () async {
      final databaseExecutor = await executor;
      return databaseExecutor.insert(
        table,
        values,
        conflictAlgorithm: replaceOnConflict ? ConflictAlgorithm.replace : null,
      );
    });
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _guard('更新数据失败', () async {
      final databaseExecutor = await executor;
      return databaseExecutor.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
      );
    });
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    return _guard('删除数据失败', () async {
      final databaseExecutor = await executor;
      return databaseExecutor.delete(table, where: where, whereArgs: whereArgs);
    });
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool distinct = false,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    return _guard('查询数据失败', () async {
      final databaseExecutor = await executor;
      return databaseExecutor.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    });
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, {
    List<Object?>? arguments,
  }) {
    return _guard('执行 SQL 查询失败', () async {
      final databaseExecutor = await executor;
      return databaseExecutor.rawQuery(sql, arguments);
    });
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseService service) action) {
    return _guard('执行数据库事务失败', () async {
      final databaseExecutor = await executor;
      if (databaseExecutor is Database) {
        // 从普通 Database 开启事务，并把 Transaction 包装回同一抽象接口。
        // 回调内必须使用传入的 service，所有操作才会处于同一事务。
        return databaseExecutor.transaction<T>((transaction) {
          return action(_SqliteTransactionDatabaseService(transaction));
        });
      }

      // 如果当前已经在事务中，直接复用当前事务执行，避免嵌套事务带来理解成本。
      return action(this);
    });
  }

  @override
  Future<void> clearTable(String table) async {
    // 复用 delete，让清表也获得统一异常转换。
    await delete(table);
  }

  /// 统一捕获 sqflite 异常，并转换成 DatabaseException。
  ///
  /// [message] 是不包含 SQL 参数的稳定操作说明；[action] 是真正的数据库动作。
  /// 已经转换过的 DatabaseException 原样上抛，其他插件异常保留 cause/stack 后包装，
  /// 避免事务嵌套时一层层重复包装。
  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException {
      // 内层事务已经转换过的项目异常直接上抛，避免重复包裹丢失语义。
      rethrow;
    } catch (error, stack) {
      // 保存原始 cause 和 stack，页面得到稳定异常类型，日志仍可定位根因。
      throw DatabaseException(message, cause: error, stackTrace: stack);
    }
  }
}

/// 事务中的 DatabaseService。
///
/// 它和普通 SqliteDatabaseService 的方法一样，
/// 但所有操作都会落在同一个 sqflite Transaction 上。
class _SqliteTransactionDatabaseService extends _SqliteExecutorService {
  _SqliteTransactionDatabaseService(this._transaction);

  final Transaction _transaction;

  @override
  Future<DatabaseExecutor> get executor async => _transaction;
}
