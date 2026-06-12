// lib/core/providers/repositories.dart
//
// 作用：所有 Repository 的 Riverpod Provider 声明，替代 get_it 的 registerLazySingleton。
//
// 注册的仓库：
// - HomeRepository：首页数据
// - LoginRepository：登录数据
// - ProfileRepository：个人中心数据
//
// 设计要点：
// - Repository 不持有页面状态，可以作为单例复用
// - 依赖 services.dart 中注册的 ApiService 等底层服务
// - 通过 ref.read 获取依赖，编译时保证依赖存在
//
// 使用方式：
// ```dart
// // 在 Notifier 的方法中通过 ref 获取
// final banners = await ref.read(homeRepositoryProvider).fetchBanners();
// ```

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/repository/home_repository.dart';
import '../../features/login/repository/login_repository.dart';
import '../../features/profile/repository/profile_repository.dart';
import 'services.dart';

/// 首页数据仓库。
///
/// 提供 Banner 列表等首页数据，实现缓存优先策略。
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(apiService: ref.read(apiServiceProvider));
});

/// 登录数据仓库。
///
/// 提供登录/注册等鉴权接口。
final loginRepositoryProvider = Provider<LoginRepository>((ref) {
  return LoginRepositoryImpl(apiService: ref.read(apiServiceProvider));
});

/// 个人中心数据仓库。
///
/// 提供用户详细资料等接口。
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(apiService: ref.read(apiServiceProvider));
});
