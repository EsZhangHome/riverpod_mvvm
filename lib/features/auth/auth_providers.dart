// lib/features/auth/auth_providers.dart
//
// Auth 模块的 Repository 依赖组装入口。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import 'repository/login_repository.dart';

/// 登录 Repository。ViewModel 依赖抽象接口，不直接接触 ApiService。
final loginRepositoryProvider = Provider<LoginRepository>((ref) {
  return LoginRepositoryImpl(ref.watch(apiServiceProvider));
});
