// Login 子模块的依赖组装入口。
//
// 登录业务只在这里决定 Repository 的生产实现；页面、ViewModel 和 Application
// 用例都依赖稳定抽象。全局会话依赖位于相邻的 session 子模块，不放进本文件。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/service_providers.dart';
import 'repository/login_repository.dart';

/// 登录 Repository 的依赖注入入口。
///
/// SignInUseCase 使用 [LoginRepository] 抽象；这里才创建 [LoginRepositoryImpl] 并
/// 注入全局 ApiService。用例测试可以替换本 Provider，ViewModel 测试则直接替换
/// 更上层的 signInProvider，让每层测试只关注自己的协作关系。
final loginRepositoryProvider = Provider<LoginRepository>((ref) {
  return LoginRepositoryImpl(ref.watch(apiServiceProvider));
});
