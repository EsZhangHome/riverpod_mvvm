// Auth Feature 内部的应用用例组装点。
//
// application 只声明抽象，Repository 和 ViewModel 各自实现自己的职责；只有本文件
// 同时知道这些具体对象，并通过 Riverpod 把它们连接起来。这样 LoginNotifier 不会
// 直接 new Repository，也不会直接依赖 AuthNotifier。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/sign_in_use_case.dart';
import 'auth_providers.dart';
import 'view_model/auth_view_model.dart';

/// 登录应用用例的依赖注入入口。
///
/// 返回类型是 [SignIn] 抽象，调用方看不到默认实现的构造细节。测试可以 override
/// 本 Provider 验证 LoginNotifier，而不需要同时创建 Repository、安全存储和全局
/// AuthNotifier；用例自己的协作顺序由独立单元测试覆盖。
final signInProvider = Provider<SignIn>((ref) {
  return SignInUseCase(
    loginRepository: ref.watch(loginRepositoryProvider),
    // AuthNotifier 实现 SessionActivator，但这里只把它作为抽象端口传入用例。
    sessionActivator: ref.read(authProvider.notifier),
  );
});
