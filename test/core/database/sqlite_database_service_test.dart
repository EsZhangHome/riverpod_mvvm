// SQLite 服务集成测试。
//
// 使用内存数据库验证项目封装，不触碰设备真实文件。测试关注 CRUD、事务和
// 异常边界；sqflite_common_ffi 自身的 SQL 正确性不在这里重复测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/database/database_exception.dart'
    as app_database;
import 'package:riverpod_mvvm/core/database/sqlite_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late SqliteDatabaseService service;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    // 每个测试使用全新的内存库，互不共享行数据或事务状态。
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute(
      'CREATE TABLE notes (id INTEGER PRIMARY KEY, title TEXT NOT NULL)',
    );
    service = SqliteDatabaseService(databaseProvider: () async => database);
  });

  tearDown(() => database.close());

  test('CRUD methods share the DatabaseService abstraction', () async {
    final id = await service.insert('notes', {'title': 'first'});
    expect(id, 1);

    var rows = await service.query('notes', where: 'id = ?', whereArgs: [id]);
    expect(rows.single['title'], 'first');

    final updated = await service.update(
      'notes',
      {'title': 'updated'},
      where: 'id = ?',
      whereArgs: [id],
    );
    expect(updated, 1);

    rows = await service.rawQuery(
      'SELECT title FROM notes WHERE id = ?',
      arguments: [id],
    );
    expect(rows.single['title'], 'updated');

    expect(await service.delete('notes', where: 'id = ?', whereArgs: [id]), 1);
    expect(await service.query('notes'), isEmpty);
  });

  test('failed transaction rolls back all writes', () async {
    // action 抛错后，sqflite 回滚插入；服务层再把原始错误包装成项目异常。
    await expectLater(
      service.transaction<void>((transaction) async {
        await transaction.insert('notes', {'title': 'temporary'});
        throw StateError('force rollback');
      }),
      throwsA(isA<app_database.DatabaseException>()),
    );

    expect(await service.query('notes'), isEmpty);
  });

  test('nested transaction reuses the current transaction executor', () async {
    await service.transaction<void>((transaction) async {
      await transaction.insert('notes', {'title': 'outer'});
      await transaction.transaction<void>((nested) async {
        await nested.insert('notes', {'title': 'inner'});
      });
    });

    final rows = await service.query('notes', orderBy: 'id ASC');
    expect(rows.map((row) => row['title']), ['outer', 'inner']);
  });

  test('plugin errors are converted to DatabaseException', () async {
    await expectLater(
      service.query('missing_table'),
      throwsA(
        isA<app_database.DatabaseException>()
            .having((error) => error.message, 'message', '查询数据失败')
            .having((error) => error.cause, 'cause', isNotNull),
      ),
    );
  });
}
