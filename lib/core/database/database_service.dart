// lib/core/database/database_service.dart
//
// 作用：定义数据库能力抽象。
//
// Repository 只依赖 DatabaseService，不直接依赖 sqflite。
// 这样测试时可以注册 FakeDatabaseService，未来也可以把 sqflite 替换成 drift。

/// 数据库服务抽象接口。
///
/// 这里只提供中型项目最常用的 CRUD 能力，不做过度封装。
/// 复杂查询可以用 rawQuery，但推荐优先把 SQL 收敛在 Repository 内部。
abstract class DatabaseService {
  /// 插入一条数据。
  ///
  /// [replaceOnConflict] 为 true 时，如果主键冲突，会用新数据覆盖旧数据。
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceOnConflict = false,
  });

  /// 更新数据。
  ///
  /// [where] 和 [whereArgs] 用来限制更新范围。
  /// 不传 where 会更新整张表，业务代码要谨慎使用。
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  });

  /// 删除数据。
  ///
  /// 不传 where 会删除整张表，业务代码要谨慎使用。
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs});

  /// 查询数据。
  ///
  /// 返回 Map 列表，Repository 负责把 Map 转成业务 Model。
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool distinct = false,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  });

  /// 执行自定义 SQL 查询。
  ///
  /// 用于 join、聚合统计等 query 方法不好表达的场景。
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, {
    List<Object?>? arguments,
  });

  /// 在事务中执行多个数据库操作。
  ///
  /// 事务里的操作要使用回调参数 [service]，不要使用外层 DatabaseService。
  Future<T> transaction<T>(Future<T> Function(DatabaseService service) action);

  /// 清空某张表。
  ///
  /// 常用于退出登录时清理用户相关缓存。
  Future<void> clearTable(String table);
}
