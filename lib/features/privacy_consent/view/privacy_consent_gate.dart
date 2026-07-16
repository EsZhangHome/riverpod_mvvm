import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/ui/loading_view.dart';
import '../view_model/privacy_consent_view_model.dart';

/// MyApp 前面的首次登录准备门，不再负责自动展示隐私协议。
///
/// App 首次打开时，本组件先完成会话安全准备，再由 MyApp 进入登录页并自动显示
/// 协议。因此这里不直接画弹窗，只负责一件事：如果从未同意过任何政策，先清除
/// 安全存储中可能残留的旧会话，再创建 MyApp。这样普通偏好被清除、但 iOS
/// Keychain 仍保留 token 时，
/// 也不会绕过登录页直接恢复首页。
///
/// 首次自动弹窗、登录动作再次触发和政策升级都由 MyApp 内的 PrivacyConsentHost
/// 处理；登录页的 `beforeLogin` 回调负责拒绝后的再次请求。各入口共享同一个
/// privacyConsentProvider，不会产生多份授权状态。
final class PrivacyConsentGate extends ConsumerStatefulWidget {
  const PrivacyConsentGate({
    super.key,
    required this.child,
    this.onPrepareInitialLogin,
  });

  /// 会话准备完成后才进入 Widget 树的业务 App。
  final Widget child;

  /// 首次无隐私记录时、创建 MyApp 前执行的会话清理动作。
  ///
  /// BootstrapGate 注入 SessionStore.clear；独立 Widget 测试可以省略。清理失败会
  /// 显示可重试错误页，不能冒险恢复旧会话后直接进入业务首页。
  final Future<void> Function()? onPrepareInitialLogin;

  @override
  ConsumerState<PrivacyConsentGate> createState() => _PrivacyConsentGateState();
}

final class _PrivacyConsentGateState extends ConsumerState<PrivacyConsentGate> {
  /// Future 缓存在 State 中，避免父组件重建时重复清理 SessionStore。
  Future<void>? _preparation;

  Future<void> _prepare() => (widget.onPrepareInitialLogin ?? _noPreparation)();

  void _retry() {
    // setState 的回调必须是同步 void。这里只把新 Future 保存进 State，真正的异步
    // 等待仍交给 FutureBuilder；不能用表达式闭包把 Future 作为 setState 返回值。
    setState(() {
      _preparation = _prepare();
    });
  }

  @override
  Widget build(BuildContext context) {
    final privacyState = ref.watch(privacyConsentProvider);

    // 已同意当前版本或存在历史版本时，不属于“全新首次登录”，会话按正常流程恢复。
    // 旧版本的升级提醒由业务树最上方的 UpgradeHost 负责，不在这里清会话。
    if (_preparation == null && privacyState.hasAcceptedAnyPolicy) {
      return widget.child;
    }

    _preparation ??= _prepare();
    return FutureBuilder<void>(
      future: _preparation,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PreparationMaterialApp(child: LoadingView());
        }
        if (snapshot.hasError) {
          return _PreparationMaterialApp(
            child: _PreparationFailureView(onRetry: _retry),
          );
        }
        // 准备完成后即使仍未同意政策也创建 MyApp，让认证状态进入未登录并显示登录页。
        // Warmup 仍检查 hasAcceptedCurrentPolicy，因此不会在首次同意前启动敏感 SDK。
        return widget.child;
      },
    );
  }
}

final class _PreparationMaterialApp extends StatelessWidget {
  const _PreparationMaterialApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: EnvConfig.appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SafeArea(child: child)),
    );
  }
}

final class _PreparationFailureView extends StatelessWidget {
  const _PreparationFailureView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              strings.privacyLoginPreparationFailed,
              key: const ValueKey('privacy.preparationError'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('privacy.preparationRetry'),
              onPressed: onRetry,
              child: Text(strings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _noPreparation() async {}
