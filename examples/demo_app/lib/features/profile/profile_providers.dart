// lib/features/profile/profile_providers.dart
//
// Profile 模块的 Repository 依赖组装入口。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:riverpod_mvvm/core/providers/service_providers.dart';
import 'repository/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(apiServiceProvider));
});
