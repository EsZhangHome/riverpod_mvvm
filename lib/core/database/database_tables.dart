// lib/core/database/database_tables.dart
//
// 作用：集中管理数据库表名和字段名。
//
// 为什么要单独放一个文件：
// - 避免在 Repository 里到处手写字符串
// - 表名或字段名变更时，能快速定位影响范围
// - 写 SQL、查询条件、数据转换时都复用同一份常量

/// 数据库表名和字段名常量。
///
/// 这里只放“名字”，不放 SQL 逻辑。
/// 真正的建表语句放在 database_migrations.dart 中。
class DatabaseTables {
  const DatabaseTables._();

  // ==================== 通用缓存表 ====================

  /// 通用缓存表。
  ///
  /// 适合缓存一些简单 JSON 数据，例如首页配置、接口快照、字典数据。
  /// 如果某个模块数据结构复杂，建议为该模块单独建表，不要全部塞进这里。
  static const String appCache = 'app_cache';

  /// 缓存 key。
  ///
  /// 例如：home_banners、user_profile、order_filter_config。
  static const String cacheKey = 'cache_key';

  /// 缓存内容。
  ///
  /// 通常存 JSON 字符串，由 Repository 负责 encode / decode。
  static const String cacheValue = 'cache_value';

  /// 缓存更新时间。
  ///
  /// 使用毫秒时间戳，方便判断缓存是否过期。
  static const String cacheUpdatedAt = 'updated_at';
}
