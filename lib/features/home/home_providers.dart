// lib/features/home/home_providers.dart
//
// Home 模块的依赖组装入口。
// Repository Provider 跟随业务模块放置，避免 core 反向依赖具体业务。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/cache_policy.dart';
import '../../core/providers/service_providers.dart';
import 'model/home_banner.dart';
import 'repository/home_repository.dart';
import 'repository/product_repository.dart';

/// Banner 的内存缓存策略；测试可通过 override 替换有效期或实现。
final homeBannerCacheProvider = Provider<CachePolicy<List<HomeBanner>>>((ref) {
  return MemoryCachePolicy<List<HomeBanner>>(
    duration: const Duration(minutes: 5),
  );
});

/// 首页网络 Repository，由 Home 模块自己声明并依赖 core 的基础服务。
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(
    ref.watch(apiServiceProvider),
    ref.watch(homeBannerCacheProvider),
  );
});

/// 商品目录 Repository；当前使用本地实现，未来可在这里切换为接口实现。
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return LocalProductRepository();
});
