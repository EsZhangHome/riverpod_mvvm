import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/cache/database_cache_policy.dart';
import 'package:riverpod_mvvm/core/database/database_service.dart';
import 'package:riverpod_mvvm/core/database/database_tables.dart';

/// 只实现本测试需要的 app_cache 行为。
///
/// 测试目标是 CachePolicy 的过期、损坏恢复和 key 隔离，不重复测试 sqflite；真实插件
/// 是否能在设备运行由 integration_test 的基础设施冒烟测试负责。
final class _FakeDatabaseService implements DatabaseService {
  final Map<String, Map<String, Object?>> rows = {};

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceOnConflict = false,
  }) async {
    expect(table, DatabaseTables.appCache);
    final key = values[DatabaseTables.cacheKey]! as String;
    rows[key] = Map<String, Object?>.from(values);
    return 1;
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
  }) async {
    expect(table, DatabaseTables.appCache);
    final row = rows[whereArgs!.single];
    if (row == null) return [];
    return [
      if (columns == null)
        Map<String, Object?>.from(row)
      else
        {for (final column in columns) column: row[column]},
    ];
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    expect(table, DatabaseTables.appCache);
    return rows.remove(whereArgs!.single) == null ? 0 : 1;
  }

  @override
  Future<void> clearTable(String table) async => rows.clear();

  @override
  Future<T> transaction<T>(
    Future<T> Function(DatabaseService service) action,
  ) => action(this);

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, {
    List<Object?>? arguments,
  }) => throw UnimplementedError();

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) => throw UnimplementedError();
}

void main() {
  late _FakeDatabaseService database;
  late DateTime now;
  late DatabaseCachePolicy<String> cache;

  setUp(() {
    database = _FakeDatabaseService();
    now = DateTime(2026, 7, 16, 10);
    cache = DatabaseCachePolicy<String>(
      database: database,
      cacheKey: 'tenant:a:greeting',
      duration: const Duration(minutes: 5),
      encode: (value) => value,
      decode: (value) => value,
      now: () => now,
    );
  });

  test('write and read a non-expired value', () async {
    await cache.writeCache('hello');

    expect(await cache.readCache(), 'hello');
    expect(
      database.rows['tenant:a:greeting']![DatabaseTables.cacheUpdatedAt],
      now.millisecondsSinceEpoch,
    );
  });

  test('expired value is deleted and reported as cache miss', () async {
    await cache.writeCache('old');
    now = now.add(const Duration(minutes: 5));

    expect(await cache.readCache(), isNull);
    expect(database.rows, isEmpty);
  });

  test(
    'invalid persisted shape is cleared instead of crashing forever',
    () async {
      database.rows['tenant:a:greeting'] = {
        DatabaseTables.cacheKey: 'tenant:a:greeting',
        DatabaseTables.cacheValue: 123,
        DatabaseTables.cacheUpdatedAt: now.millisecondsSinceEpoch,
      };

      expect(await cache.readCache(), isNull);
      expect(database.rows, isEmpty);
    },
  );

  test('decoder failure clears an incompatible old model', () async {
    final incompatible = DatabaseCachePolicy<String>(
      database: database,
      cacheKey: 'model',
      duration: const Duration(minutes: 5),
      encode: (value) => value,
      decode: (_) => throw const FormatException('old schema'),
      now: () => now,
    );
    await incompatible.writeCache('v1');

    expect(await incompatible.readCache(), isNull);
    expect(database.rows, isEmpty);
  });

  test('clear only deletes the current cache key', () async {
    await cache.writeCache('mine');
    database.rows['tenant:b:greeting'] = {
      DatabaseTables.cacheKey: 'tenant:b:greeting',
      DatabaseTables.cacheValue: 'other',
      DatabaseTables.cacheUpdatedAt: now.millisecondsSinceEpoch,
    };

    await cache.clearCache();

    expect(database.rows.keys, ['tenant:b:greeting']);
  });

  test('rejects empty keys and non-positive durations', () {
    expect(
      () => DatabaseCachePolicy<String>(
        database: database,
        cacheKey: '  ',
        duration: const Duration(minutes: 1),
        encode: (value) => value,
        decode: (value) => value,
      ),
      throwsArgumentError,
    );
    expect(
      () => DatabaseCachePolicy<String>(
        database: database,
        cacheKey: 'key',
        duration: Duration.zero,
        encode: (value) => value,
        decode: (value) => value,
      ),
      throwsArgumentError,
    );
  });
}
