// lib/features/login/view/login_page.dart
//
// 作用：登录页面，提供账号密码输入和登录按钮。
//
// 页面执行步骤：
// 1. watch loginProvider 渲染表单状态；
// 2. 点击登录时 read Notifier 并发送账号密码；
// 3. 成功后读取 LoginState，把 token/user 写入 App 级 authProvider；
// 4. AuthProvider 持久化完成后跳转商品首页；失败则留在原页显示错误。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/page_shell.dart';
import '../../../core/base/view_state.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../global/auth_provider.dart';
import '../../../shared/widgets/state_view.dart';
import '../view_model/login_view_model.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // TextEditingController 是纯 UI 状态，归 StatefulWidget 管理，不放入 Provider。
  final _accountController = TextEditingController(text: 'user@example.com');
  final _passwordController = TextEditingController(text: '123456');

  @override
  void dispose() {
    // 页面销毁时释放原生文本输入资源，避免 Controller 泄漏。
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
                AppStrings.appName,
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

    // 步骤 4：交给 App 级 AuthNotifier，同时更新内存状态与本地安全存储。
    await ref.read(authProvider.notifier).loginSuccess(token, user);

    // 步骤 5：持久化完成且页面仍存在时，使用 go 替换登录路由。
    if (mounted) {
      context.go(RoutePaths.mainHome);
    }
  }
}
