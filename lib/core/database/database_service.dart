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
  /// - [table]：目标表名，推荐使用 DatabaseTables 常量，不要拼接外部输入；
  /// - [values]：字段名到数据库值的映射，Repository 负责从 Model 转换；
  /// - [replaceOnConflict]：true 时主键/唯一索引冲突会替换旧行，false 时按 SQLite
  ///   默认策略抛错。
  ///
  /// 返回新行 rowId；失败时实现应抛 DatabaseException。
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceOnConflict = false,
  });

  /// 更新数据。
  ///
  /// - [table]：目标表；
  /// - [values]：需要更新的字段和值；
  /// - [where]：不带 `WHERE` 关键字的条件，例如 `id = ?`；
  /// - [whereArgs]：依次替换条件中的 `?`，避免直接拼接用户输入造成 SQL 注入。
  ///
  /// 不传 [where] 会更新整张表，业务代码要谨慎使用。返回受影响行数。
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  });

  /// 删除数据。
  ///
  /// [table]、[where]、[whereArgs] 含义与 update 相同。不传 where 会删除整张表；
  /// 若意图明确是清表，优先调用 [clearTable] 让代码语义更清楚。返回删除行数。
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs});

  /// 查询数据。
  ///
  /// - [table]：目标表；
  /// - [distinct]：是否对最终结果执行 DISTINCT 去重；
  /// - [columns]：只返回指定字段，null 表示 `*`；
  /// - [where]/[whereArgs]：过滤条件及其安全占位参数；
  /// - [orderBy]：排序表达式，例如 `created_at DESC`；
  /// - [limit]：最多返回多少行，null 表示不限制；
  /// - [offset]：跳过多少行，通常和 limit 组合做分页。
  ///
  /// 返回数据库行 Map 列表；Repository 负责字段校验和 Model 转换。不要把返回的
  /// Map 直接泄漏给 ViewModel/View。
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
  /// [sql] 用于 join、聚合统计等 query 方法不好表达的只读语句；动态值仍应写成
  /// `?`，并通过 [arguments] 绑定。返回行 Map 列表。
  ///
  /// 本接口名为 rawQuery，只应用于有结果集的查询；insert/update/delete 仍使用
  /// 对应方法，避免业务层散落难以审计的任意 SQL。
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, {
    List<Object?>? arguments,
  });

  /// 在事务中执行多个数据库操作。
  ///
  /// [action] 收到绑定当前事务的 [service]。回调内所有操作都必须使用这个参数，
  /// 不要使用外层 DatabaseService，否则那些操作可能不属于同一事务。
  ///
  /// action 正常返回时提交并返回 T；action 抛错时回滚并继续抛出 DatabaseException。
  /// 当前实现遇到嵌套 transaction 时会复用外层事务，而不是创建保存点。
  Future<T> transaction<T>(Future<T> Function(DatabaseService service) action);

  /// 清空某张表。
  ///
  /// [table] 是明确要清空的表名。常用于退出登录时清理用户缓存；如果表内同时
  /// 保存多个用户的数据，应使用带 where 的 delete，不能误删其他账号数据。
  Future<void> clearTable(String table);
}
