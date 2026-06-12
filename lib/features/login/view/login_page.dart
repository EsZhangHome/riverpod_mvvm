// lib/features/login/view/login_page.dart
//
// 作用：登录页面，提供账号密码输入和登录按钮。
//
// 迁移说明（Provider → Riverpod）：
// - locator<LoginViewModel>() → loginProvider
// - context.read<AuthProvider>() → ref.read(authProvider)
// - BasePage → PageShell
// - LoadingStyle.overlay + StateView 直接在 build 中使用

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/base_page.dart';
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
  final _accountController = TextEditingController(text: 'user@example.com');
  final _passwordController = TextEditingController(text: '123456');

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.login)),
      body: StateView(
        state: state.viewState,
        errorMessage: state.errorMessage,
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
    final notifier = ref.read(loginProvider.notifier);
    final success = await notifier.login(
      _accountController.text,
      _passwordController.text,
    );

    if (!mounted || !success) return;

    final loginState = ref.read(loginProvider);
    final token = loginState.token;
    final user = loginState.user;
    if (token == null || user == null) return;

    await ref.read(authProvider.notifier).loginSuccess(token, user);

    if (mounted) {
      context.go(RoutePaths.mainHome);
    }
  }
}
