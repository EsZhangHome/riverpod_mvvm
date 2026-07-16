// lib/features/home/repository/home_repository.dart
//
// 作用：首页数据仓库，负责获取首页数据（Banner 列表），并实现缓存优先策略。
//
// 架构职责：
// - 定义 HomeRepository 接口（ViewModel 依赖接口，方便测试）
// - 实现 HomeRepositoryImpl（当前使用模拟数据，接入真实后端时替换）
// - 实现缓存优先策略：有缓存时先返回缓存，同时后台拉取新数据
//
// 缓存策略说明：
// 1. 先尝试读取缓存（MemoryCachePolicy，有效期 5 分钟）
// 2. 有缓存 → 立即返回缓存数据，同时后台静默拉取新数据
//    - 后台拉取成功：更新缓存，但本次不触发 UI 刷新（下次打开才看到新数据）
//    - 后台拉取失败：忽略错误，用户看到的是缓存数据
// 3. 无缓存 → 等待远端数据返回，HomeNotifier 会进入 loading 状态
//
// 接入真实后端的方式：
// 取消 _fetchRemoteBanners 中的模拟数据注释，替换为下面注释中的 _apiService.get 调用。
// 只需要修改这个方法，ViewModel 和 Page 不需要任何改动。

import 'package:dio/dio.dart';

import '../../../core/cache/cache_policy.dart';
import '../../../core/config/env_config.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/endpoints.dart';
import '../model/home_banner.dart';

/// 首页仓库接口。
///
/// ViewModel 依赖这个接口，测试时可以传入 FakeHomeRepository。
abstract class HomeRepository {
  /// 获取首页 Banner 列表。
  ///
  /// [cancelToken]：取消令牌，页面销毁时取消请求。
  ///
  /// 返回 Banner 列表，可能来自缓存或网络。
  Future<List<HomeBanner>> fetchBanners({CancelToken? cancelToken});
}

/// 首页数据仓库实现。
///
/// 实现缓存优先策略，让用户打开首页时能立即看到内容（即使网络较慢）。
/// 以后首页接口变复杂（如多个接口、分页等），也只在这里处理数据来源。
class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._apiService, this._cachePolicy);

  /// 网络服务，通过 DI 注入。Mock 模式下不会被调用。
  final ApiService _apiService;

  /// 缓存策略（默认内存缓存，有效期 5 分钟）
  final CachePolicy<List<HomeBanner>> _cachePolicy;

  @override
  Future<List<HomeBanner>> fetchBanners({CancelToken? cancelToken}) async {
    final cachedData = await _cachePolicy.readCache();
    if (cachedData != null) {
      Future<void>(() async {
        try {
          await _fetchRemoteBanners(cancelToken: cancelToken);
        } catch (_) {}
      });
      return cachedData;
    }
    return _fetchRemoteBanners(cancelToken: cancelToken);
  }

  /// 获取远端 Banner 数据，根据 EnvConfig.enableMock 决定使用 Mock 还是真实接口。
  Future<List<HomeBanner>> _fetchRemoteBanners({
    CancelToken? cancelToken,
  }) async {
    if (EnvConfig.enableMock) {
      return _fetchMockBanners();
    }
    return _fetchApiBanners(cancelToken: cancelToken);
  }

  /// Mock 数据（演示/开发阶段使用）。
  Future<List<HomeBanner>> _fetchMockBanners() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    const banners = [
      HomeBanner(id: '1', title: 'Riverpod 统一状态管理和依赖注入', imageUrl: ''),
      HomeBanner(id: '2', title: 'MVVM 让页面和业务状态分离', imageUrl: ''),
      HomeBanner(id: '3', title: 'Repository 统一数据获取和转换', imageUrl: ''),
    ];
    await _cachePolicy.writeCache(banners);
    return banners;
  }

  /// 真实后端数据。
  Future<List<HomeBanner>> _fetchApiBanners({CancelToken? cancelToken}) async {
    final response = await _apiService.get<List<HomeBanner>>(
      Endpoints.homeBanners,
      cancelToken: cancelToken,
      fromJson: (json) => (json as List<dynamic>)
          .map((item) => HomeBanner.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    final data = response.data ?? [];
    await _cachePolicy.writeCache(data);
    return data;
  }
}
