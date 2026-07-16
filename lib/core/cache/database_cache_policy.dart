// lib/core/cache/database_cache_policy.dart
//
// 作用：使用底座已有的 app_cache 表实现“可选的单值持久化缓存”。
//
// 这里没有注册全局 Provider，也不会自动缓存所有请求。缓存是否必要、缓存多久、
// 如何按用户或查询条件隔离，属于具体业务决策，应由项目组合层为某个 Repository
// 显式创建本类。删除 Demo 后，本类仍是一项通用能力，但不会产生运行时开销。

import '../database/database_service.dart';
import '../database/database_tables.dart';
import 'cache_policy.dart';

/// 把强类型业务对象保存为字符串的序列化函数。
///
/// 通常写法是 `(value) => jsonEncode(value.toJson())`；列表需要先把每个元素转成 Map。
typedef CacheEncoder<T> = String Function(T value);

/// 把数据库中的字符串恢复为强类型业务对象的反序列化函数。
///
/// 通常写法是 `(value) => Model.fromJson(jsonDecode(value) as Map<...>)`。
typedef CacheDecoder<T> = T Function(String value);

/// 基于 SQLite `app_cache` 表的单值持久化缓存策略。
///
/// 与 [MemoryCachePolicy] 的区别：App 被系统回收或用户重新打开后，本缓存仍存在。
/// 它适合接口快照、字典和非敏感配置，不适合 token、密码等秘密数据；敏感信息必须
/// 使用 SecureStorageService。复杂、需要 SQL 查询的领域数据应建立独立表，而不是
/// 全部序列化后塞进通用缓存表。
final class DatabaseCachePolicy<T> implements CachePolicy<T> {
  /// 创建一个有固定 key 和有效期的持久化缓存。
  ///
  /// 参数说明：
  /// - [database]：数据库抽象，由 databaseServiceProvider 注入；测试可传 Fake；
  /// - [cacheKey]：本条缓存的唯一标识。包含用户数据时必须带 userId/tenantId，避免
  ///   切换账号后读到上一位用户的数据，例如 `profile:$tenantId:$userId`；
  /// - [duration]：从成功写入开始计算的有效期，必须大于 0；
  /// - [encode]/[decode]：业务类型 T 与可持久化字符串之间的转换规则；
  /// - [now]：当前时间函数，正式代码不传；单元测试注入固定时间以避免真实等待。
  factory DatabaseCachePolicy({
    required DatabaseService database,
    required String cacheKey,
    required Duration duration,
    required CacheEncoder<T> encode,
    required CacheDecoder<T> decode,
    DateTime Function()? now,
  }) {
    final normalizedKey = cacheKey.trim();
    if (normalizedKey.isEmpty) {
      throw ArgumentError.value(cacheKey, 'cacheKey', '不能为空');
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', '必须大于零');
    }
    return DatabaseCachePolicy<T>._(
      database: database,
      cacheKey: normalizedKey,
      duration: duration,
      encode: encode,
      decode: decode,
      now: now ?? DateTime.now,
    );
  }

  /// 真正保存依赖的私有构造函数。
  ///
  /// 公共 factory 先完成参数校验和 key 标准化；这里使用 initializing formal，既
  /// 保持字段私有，也不会为了满足 lint 把数据库和编解码器扩大成公共 API。
  DatabaseCachePolicy._({
    required this._database,
    required this._cacheKey,
    required this._duration,
    required this._encode,
    required this._decode,
    required this._now,
  });

  final DatabaseService _database;
  final String _cacheKey;
  final Duration _duration;
  final CacheEncoder<T> _encode;
  final CacheDecoder<T> _decode;
  final DateTime Function() _now;

  @override
  Future<T?> readCache() async {
    // 只按主键读取一行，避免扫描整张缓存表。columns 明确限制返回字段，减少无意义
    // 数据复制，也让下面的格式校验边界更清楚。
    final rows = await _database.query(
      DatabaseTables.appCache,
      columns: [DatabaseTables.cacheValue, DatabaseTables.cacheUpdatedAt],
      where: '${DatabaseTables.cacheKey} = ?',
      whereArgs: [_cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final value = row[DatabaseTables.cacheValue];
    final updatedAtMilliseconds = row[DatabaseTables.cacheUpdatedAt];

    // 类型不匹配通常说明旧版本缓存结构或数据损坏。缓存不是事实来源，因此最安全
    // 的恢复方式是删除这一条并返回 miss，让 Repository 重新请求；数据库查询本身
    // 的异常不会被吞掉，仍由上层按存储失败处理。
    if (value is! String || updatedAtMilliseconds is! int) {
      await clearCache();
      return null;
    }

    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      updatedAtMilliseconds,
    );
    if (_now().difference(updatedAt) >= _duration) {
      await clearCache();
      return null;
    }

    try {
      return _decode(value);
    } on Object {
      // App 升级后 Model 字段变化可能让旧 JSON 无法解析。它不是数据库不可用，也
      // 不应让页面永久报错；清除后回源即可。需要无损迁移的核心业务数据不应使用
      // 这种通用 CachePolicy，而应建立带版本迁移的领域表。
      await clearCache();
      return null;
    }
  }

  @override
  Future<void> writeCache(T data) async {
    // 先编码再写库。编码失败时数据库旧值保持不变；insert 成功后 value 和时间戳
    // 在同一行一起替换，不会出现“新数据配旧时间”的半更新状态。
    final encoded = _encode(data);
    await _database.insert(DatabaseTables.appCache, {
      DatabaseTables.cacheKey: _cacheKey,
      DatabaseTables.cacheValue: encoded,
      DatabaseTables.cacheUpdatedAt: _now().millisecondsSinceEpoch,
    }, replaceOnConflict: true);
  }

  @override
  Future<void> clearCache() async {
    // 只删除本策略拥有的 key。退出登录若要清理一组用户缓存，应由认证应用用例
    // 统一调用对应策略，而不是在这里直接 clearTable 误删其他租户/公共缓存。
    await _database.delete(
      DatabaseTables.appCache,
      where: '${DatabaseTables.cacheKey} = ?',
      whereArgs: [_cacheKey],
    );
  }
}
