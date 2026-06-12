// lib/core/database/sqlite_database_service.dart
//
// 作用：DatabaseService 的 sqflite 实现。
//
// 只有这个文件直接依赖 sqflite。
// Repository、ViewModel、View 都不应该 import sqflite。

import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'app_database.dart';
import 'database_exception.dart';
import 'database_service.dart';

/// sqflite 数据库服务实现。
///
/// 默认从 AppDatabase 获取数据库实例。
/// 测试时也可以传入自定义 databaseProvider。
class SqliteDatabaseService extends _SqliteExecutorService {
  SqliteDatabaseService({Future<Database> Function()? databaseProvider})
    : _databaseProvider = databaseProvider ?? (() => AppDatabase.database);

  final Future<Database> Function() _databaseProvider;

  @override
  Future<DatabaseExecutor> get executor => _databaseProvider();
}

/// 基于 DatabaseExecutor 的通用实现。
///
/// sqflite 的 Database 和 Transaction 都实现了 DatabaseExecutor，
/// 所以普通操作和事务操作可以复用同一套 CRUD 代码。
abstract class _SqliteExecutorService implements DatabaseService {
  Future<DatabaseExecutor> get executor;

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceOnConflict = false,
  }) {
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
    await delete(table);
  }

  /// 统一捕获 sqflite 异常，并转换成 DatabaseException。
  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException {
      rethrow;
    } catch (error, stack) {
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
