// lib/features/auth/view/login_page.dart
//
// 作用：登录页面，提供账号密码输入和登录按钮。
//
// 页面执行步骤：
// 1. watch loginProvider 渲染表单状态；
// 2. 点击登录时 read Notifier 并发送账号密码；
// 3. 成功后读取 LoginState，把 token/user 写入 App 级 authProvider；
// 4. AuthNotifier 持久化并更新登录态；GoRouter 守卫自动进入当前业务首页。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env_config.dart';
import '../../../shared/state/view_state.dart';
import '../../../shared/localization/app_strings.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/ui/state_view.dart';
import '../view_model/auth_view_model.dart';
import '../view_model/login_view_model.dart';

/// 登录模块的 View，只负责收集输入、展示 [LoginState] 和发送用户操作。
///
/// 页面不直接调用 Dio，也不保存全局登录态：
/// - 临时的登录请求状态由 autoDispose 的 loginProvider 管理；
/// - 成功后的长期会话由 App 级 authProvider 管理；
/// - 页面离开时 LoginNotifier 会释放请求处理器并取消未完成请求。
class LoginPage extends ConsumerStatefulWidget {
  /// 创建登录页。
  ///
  /// [key] 是 Flutter 用来识别 Widget 身份的可选键，通常由路由框架管理；业务调用
  /// 不需要手工传。页面没有接收“登录成功跳转地址”，因为跳转目标由统一路由守卫
  /// 根据 AppRouteBundle 决定，认证模块不应知道项目首页路径。
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // TextEditingController 是纯 UI 状态，归 StatefulWidget 管理，不放入 Provider。
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    // 页面销毁时释放原生文本输入资源，避免 Controller 泄漏。
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 构建当前登录界面。
  ///
  /// [context] 只用于读取 Theme、MediaQuery 等 Widget 树信息；Riverpod 状态使用
  /// State 自带的 [ref] 读取。每次 loginProvider 状态变化都会重新执行 build，但两个
  /// TextEditingController 保存在 State 中，不会因重建而丢失用户输入。
  @override
  Widget build(BuildContext context) {
    // watch 建立订阅：ViewState 或错误文案变化时页面自动重建。
    final state = ref.watch(loginProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.login)),
      body: StateView(
        state: state.viewState,
        errorMessage: state.errorMessage,
        // overlay 保留表单内容，只在提交期间盖一层 loading，避免界面闪烁。
        loadingStyle: LoadingStyle.overlay,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                EnvConfig.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextField(
                controller: _accountController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: AppStrings.account,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.password,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                // loading 时禁用按钮，UI 层先阻止连续点击；Handler 还有第二层防重。
                onPressed: state.viewState == ViewState.loading
                    ? null
                    : () => _login(),
                child: const Text(AppStrings.login),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    // 步骤 1：read 只发送一次登录命令，不建立额外 Widget 订阅。
    final notifier = ref.read(loginProvider.notifier);
    final success = await notifier.login(
      _accountController.text,
      _passwordController.text,
    );

    // 步骤 2：异步返回后先检查 Widget 生命周期和业务结果。
    if (!mounted || !success) return;

    // 步骤 3：读取刚写入的成功结果；缺少 token/user 时不创建残缺会话。
    final loginState = ref.read(loginProvider);
    final token = loginState.token;
    final user = loginState.user;
    if (token == null || user == null) return;

    // 步骤 4：交给 App 级 AuthNotifier；先安全保存完整会话，成功后再更新内存状态。
    final persisted = await ref
        .read(authProvider.notifier)
        .loginSuccess(token, user);
    if (!mounted) return;
    if (!persisted) {
      ref.read(loginProvider.notifier).showSessionStorageError();
    }

    // 这里故意不写 `context.go('/main/home')`：登录页属于通用 auth 模块，
    // 不应该知道任何项目的具体首页。AuthState 更新后，MyApp 的
    // App 根部的 ref.listenManual 会通知 GoRouter 重新执行守卫，再由当前登录页
    // returnTo 或入口路由包的 authenticatedHome 决定最终目标。
  }
}
