// lib/core/cache/cache_policy.dart
//
// 作用：定义 Repository 层的通用缓存策略接口，并提供内存缓存实现。
//
// 设计思路：
// - Repository 不应该直接操作缓存（SharedPreferences/文件/数据库），
//   而是通过 CachePolicy 接口读写缓存，方便替换缓存实现。
// - 当前提供 MemoryCachePolicy 作为示例，后续可以扩展：
//   - FileCachePolicy：文件缓存，适合大体积数据
//   - DatabaseCachePolicy：数据库缓存，适合复杂查询
//   - SharedPrefsCachePolicy：轻量键值缓存，适合简单配置
//
// 使用示例（在 Repository 中）：
// ```dart
// class HomeRepositoryImpl implements HomeRepository {
//   final CachePolicy<List<HomeBanner>> _cachePolicy;
//
//   Future<List<HomeBanner>> fetchBanners() async {
//     final cached = await _cachePolicy.readCache();
//     if (cached != null) return cached;
//     final remote = await _fetchFromApi();
//     await _cachePolicy.writeCache(remote);
//     return remote;
//   }
// }
// ```

/// Repository 层通用缓存接口。
///
/// 具体缓存实现可以是内存、文件、数据库，对调用方完全透明。
/// 调用方只需要关心"读缓存、写缓存、清缓存"三个操作，不需要知道底层存储细节。
abstract class CachePolicy<T> {
  /// 读取缓存数据。
  ///
  /// 返回 null 的情况：
  /// - 从未写入过缓存
  /// - 缓存已过期（具体过期策略由实现决定）
  /// - 缓存数据格式异常无法解析
  ///
  /// 返回非 null 时，调用方可以直接使用该数据，无需额外校验。
  Future<T?> readCache();

  /// 写入缓存数据。
  ///
  /// 通常在一次成功的网络请求后调用，把新数据持久化到本地。
  /// 实现层应该记录写入时间，以便 readCache 判断是否过期。
  Future<void> writeCache(T data);

  /// 清理缓存数据。
  ///
  /// 适用场景：
  /// - 用户退出登录，需要清除所有用户相关缓存
  /// - 用户手动下拉刷新，希望强制拉取最新数据
  /// - 缓存数据格式升级，旧缓存需要清除
  Future<void> clearCache();
}

/// 简单内存缓存实现。
///
/// 特性：
/// - 数据存储在内存中，读取速度极快（同步返回）
/// - 支持过期时间：超过 duration 的缓存自动失效
/// - 进程重启后缓存丢失（这是设计如此，内存缓存不持久化）
///
/// 适用场景：
/// - 列表页"先展示旧数据，再拉新数据"的缓存优先策略
/// - 短时间内多次访问同一接口时避免重复请求
/// - 作为基础示例，演示 CachePolicy 接口的用法
///
/// 不适用场景：
/// - 需要持久化的数据（改用 SharedPrefsCachePolicy 或文件缓存）
/// - 需要跨页面共享的缓存（改用全局单例缓存）
class MemoryCachePolicy<T> implements CachePolicy<T> {
  /// [duration] 缓存有效期，超过此时间后 readCache 返回 null。
  MemoryCachePolicy({required this.duration});

  /// 缓存有效期，从写入时开始计时。
  final Duration duration;

  /// 缓存数据本体，未写入时为 null。
  T? _data;

  /// 缓存写入时间，用于判断是否过期。
  DateTime? _cachedAt;

  @override
  Future<T?> readCache() async {
    final cachedAt = _cachedAt;
    // 从未写入过缓存，直接返回 null
    if (_data == null || cachedAt == null) {
      return null;
    }
    // 检查缓存是否过期：当前时间 - 写入时间 > 有效期
    if (DateTime.now().difference(cachedAt) > duration) {
      // 过期后主动清空，避免下次 readCache 仍然读到已过期的 _data 引用
      await clearCache();
      return null;
    }
    // 缓存仍在有效期内，直接返回内存中的数据
    return _data;
  }

  @override
  Future<void> writeCache(T data) async {
    // 写入数据的同时记录当前时间戳
    // 后续 readCache 通过这个时间戳判断是否过期
    _data = data;
    _cachedAt = DateTime.now();
  }

  @override
  Future<void> clearCache() async {
    // 内存缓存清理非常简单：只需要把引用置 null
    // Dart 的 GC 会自动回收原对象，不需要额外释放资源
    _data = null;
    _cachedAt = null;
  }
}
