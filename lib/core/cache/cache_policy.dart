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
  ///
  /// 持久化实现也可以在识别到旧版本或损坏数据后清理并返回 null，但应在具体
  /// 实现的文档中明确；本接口不会自动吞掉文件、数据库等底层异常。
  /// 返回非 null 表示当前实现已经完成自己的有效期和格式检查。
  Future<T?> readCache();

  /// 写入缓存数据。
  ///
  /// 通常在一次成功的网络请求后调用，把新数据交给当前缓存实现。内存实现只
  /// 保留进程内数据；文件或数据库实现才属于持久化缓存。
  /// 若实现支持过期策略，应记录写入时间供 readCache 判断。
  /// [data] 是已完成业务解析的强类型数据，不是原始 HTTP Response。持久化实现负责
  /// 自己的序列化；如果序列化或写盘失败，应抛出异常，让 Repository 决定是否允许
  /// “网络成功但缓存失败”继续返回数据。
  Future<void> writeCache(T data);

  /// 清理缓存数据。
  ///
  /// 适用场景：
  /// - 用户退出登录，需要逐个清除与当前用户相关的缓存实例
  /// - 用户手动下拉刷新，希望强制拉取最新数据
  /// - 缓存数据格式升级，旧缓存需要清除
  Future<void> clearCache();
}

/// 简单内存缓存实现。
///
/// 特性：
/// - 数据存储在内存中，读取速度极快；为统一 CachePolicy 契约仍返回 Future
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
/// - 需要跨进程重启保留的数据（改用文件或数据库缓存）
///
/// 是否跨页面共享取决于这个实例由哪个 Riverpod Provider 持有，而不是由
/// MemoryCachePolicy 自己变成静态全局单例。
class MemoryCachePolicy<T> implements CachePolicy<T> {
  /// 创建一个进程内单值缓存。
  ///
  /// [duration] 从每次 writeCache 成功的时刻开始计算。建议传正数；传入
  /// Duration.zero 或负数不会抛错，但数据几乎会立即被判定过期。
  ///
  /// 一个实例只保存一份 T。如果需要按用户 id、查询条件或分页参数分别缓存，应由
  /// Provider family 创建多个实例，或实现支持 key 的缓存策略，不能把不同查询结果
  /// 轮流写入同一个实例。
  MemoryCachePolicy({required this.duration});

  /// 缓存有效期，从写入时开始计时。
  final Duration duration;

  /// 缓存数据本体，未写入时为 null。
  /// 因此不建议把 T 声明成可空类型；写入 null 会和“没有缓存”无法区分。
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
