// lib/features/auth/login/view/login_page.dart
//
// 作用：登录页面，提供账号密码输入和登录按钮。
//
// 页面执行步骤：
// 1. watch loginProvider 渲染表单状态；
// 2. 点击登录时 read Notifier 并发送账号密码；
// 3. LoginNotifier 调用 SignIn 用例，由用例协调接口与全局会话端口；
// 4. GoRouter 守卫观察 AuthState，自动进入当前业务首页。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env_config.dart';
import '../../../../shared/state/view_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/ui/app_toast.dart';
import '../../../../shared/ui/state_view.dart';
import '../view_model/login_view_model.dart';
import '../view_model/login_agreement_view_model.dart';
import '../model/login_input_rules.dart';

/// 登录页可以打开的协议文档类型。
///
/// Auth 只声明用户点了哪一类链接，不知道 URL、隐私 Provider 或平台 Launcher；App
/// 组合层负责把枚举映射到 Privacy Feature 的实际文档。
enum LoginAgreementDocument { privacyPolicy, userAgreement }

/// 登录请求发出前的可替换前置检查。
///
/// 返回 true 表示继续使用当前输入执行登录，false 表示本次操作已经被前置流程消费
/// （例如用户拒绝隐私政策），LoginPage 不再调用 LoginNotifier。
typedef BeforeLogin =
    Future<bool> Function(
      BuildContext context, {
      required bool agreementSelected,
    });

/// 打开登录页协议链接的可替换回调。true 表示系统已成功接管文档地址。
typedef OpenLoginAgreement =
    Future<bool> Function(
      BuildContext context,
      LoginAgreementDocument document,
    );

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
  const LoginPage({super.key, this.beforeLogin, this.openAgreement});

  /// 登录按钮点击后的前置检查，由 App 组合层注入隐私授权流程。
  ///
  /// Auth 页面只依赖函数签名，不引用 Privacy Feature。独立复用场景可以不传，
  /// 但用户必须先手动勾选复选框才能执行登录；未勾选时因为没有弹窗协调器，本次
  /// 点击会停留在当前页。完整 App 已在组合层注入默认实现。
  final BeforeLogin? beforeLogin;

  /// 隐私协议与用户协议的打开动作，由 App 组合层注入。
  final OpenLoginAgreement? openAgreement;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // TextEditingController 是纯 UI 状态，归 StatefulWidget 管理，不放入 Provider。
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();

  /// 防止隐私门禁正在等待用户选择或保存时重复点击登录、重复提交同一份凭据。
  bool _isCheckingBeforeLogin = false;

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
    // listen 负责一次性 UI 副作用，不参与页面布局：
    // - Notifier 只发布安全文案和递增 feedbackId，不依赖 BuildContext；
    // - View 收到新 id 后调用 AppToast；
    // - 相同错误连续发生时 id 仍会变化，所以每次点击都能得到反馈；
    // - 不使用 fireImmediately，页面重建或重新挂载时不会重复播放旧提示。
    ref.listen(
      loginProvider.select(
        (state) => (id: state.feedbackId, message: state.feedbackMessage),
      ),
      (previous, next) {
        if (next.id == 0 || next.id == previous?.id) return;
        final message = next.message;
        if (message == null) return;
        AppToast.showError(
          context,
          message.resolve(AppLocalizations.of(context)),
        );
      },
    );

    // watch 建立订阅：ViewState 或类型化反馈消息变化时页面自动重建。
    final state = ref.watch(loginProvider);
    final agreementSelected = ref.watch(loginAgreementSelectionProvider);
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.login)),
      body: StateView(
        state: state.viewState,
        // overlay 保留表单内容，只在提交期间盖一层 loading，避免界面闪烁。
        // 登录的校验/请求错误不会进入 ViewState.error，而是由上方 ref.listen 显示
        // Toast，因此发生错误后两个输入框仍留在屏幕上，用户可以立即修改并重试。
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
                key: const ValueKey('login.account'),
                controller: _accountController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: strings.account,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const ValueKey('login.password'),
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.password,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _AgreementSelection(
                selected: agreementSelected,
                enabled:
                    state.viewState != ViewState.loading &&
                    !_isCheckingBeforeLogin,
                onChanged: (selected) => ref
                    .read(loginAgreementSelectionProvider.notifier)
                    .setSelected(selected),
                onOpenPrivacyPolicy: () =>
                    _openAgreement(LoginAgreementDocument.privacyPolicy),
                onOpenUserAgreement: () =>
                    _openAgreement(LoginAgreementDocument.userAgreement),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                key: const ValueKey('login.submit'),
                // loading 时禁用按钮，UI 层先阻止连续点击；Handler 还有第二层防重。
                onPressed:
                    state.viewState == ViewState.loading ||
                        _isCheckingBeforeLogin
                    ? null
                    : () => _login(),
                child: Text(strings.login),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_isCheckingBeforeLogin) return;
    final wasSelected = ref.read(loginAgreementSelectionProvider);
    setState(() => _isCheckingBeforeLogin = true);

    try {
      if (!wasSelected) {
        // 未勾选时，本次点击先交给统一协议弹窗。用户同意后只由页面把复选框设为 true；
        // 如果账号密码已经完整，则继续同一次登录。如果缺少字段，本次静默结束，不调
        // LoginNotifier，因此不会出现“刚同意协议就提示请输入账号”的突兀 Toast。
        final accepted =
            await (widget.beforeLogin?.call(
                  context,
                  agreementSelected: false,
                ) ??
                Future<bool>.value(false));
        if (!mounted) return;
        ref
            .read(loginAgreementSelectionProvider.notifier)
            .setSelected(accepted);
        if (!accepted ||
            !LoginInputRules.isComplete(
              _accountController.text,
              _passwordController.text,
            )) {
          return;
        }
      } else {
        // 用户主动勾选后再点登录：前置流程把这次明确选择保存成当前授权记录。保存失败、
        // 协议升级仍在处理或其他门禁拒绝时，不发送登录请求，并取消旧勾选状态。
        final canContinue =
            await (widget.beforeLogin?.call(context, agreementSelected: true) ??
                Future<bool>.value(true));
        if (!mounted) return;
        if (!canContinue) {
          ref.read(loginAgreementSelectionProvider.notifier).unselect();
          return;
        }
      }

      // View 只负责收集输入并发送一次命令。账号校验、接口请求、SessionStore 持久化、
      // authProvider 更新都属于登录用例，由 LoginNotifier 完成。这里既不读取 token/user，
      // 也不调用 AuthNotifier，因此页面不会成为两个 ViewModel 之间的业务协调器。
      await ref
          .read(loginProvider.notifier)
          .login(_accountController.text, _passwordController.text);
    } finally {
      if (mounted) setState(() => _isCheckingBeforeLogin = false);
    }
  }

  Future<void> _openAgreement(LoginAgreementDocument document) async {
    var opened = false;
    try {
      opened =
          await (widget.openAgreement?.call(context, document) ??
              Future<bool>.value(false));
    } catch (_) {
      // 平台浏览器插件异常属于可恢复的 UI 失败。登录页不关闭、不改变勾选状态，
      // 只使用公共 Toast 给出稳定提示；技术异常不能冒泡成整页崩溃。
      opened = false;
    }
    if (!mounted || opened) return;
    AppToast.showError(
      context,
      AppLocalizations.of(context).privacyPolicyOpenFailed,
    );
  }
}

/// 登录页的二元协议选择。
///
/// 这里使用 Checkbox 而不是 Radio：当前只有“已同意/未同意”两个布尔状态，不存在
/// 多个互斥选项。两个协议标题是独立可点击按钮，便于键盘、读屏和自动化测试识别。
final class _AgreementSelection extends StatelessWidget {
  const _AgreementSelection({
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.onOpenPrivacyPolicy,
    required this.onOpenUserAgreement,
  });

  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenUserAgreement;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final linkStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          key: const ValueKey('login.agreementCheckbox'),
          value: selected,
          onChanged: enabled ? (value) => onChanged(value ?? false) : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(strings.loginAgreementPrefix),
                TextButton(
                  key: const ValueKey('login.privacyPolicyLink'),
                  style: linkStyle,
                  onPressed: enabled ? onOpenPrivacyPolicy : null,
                  child: Text(strings.privacyAgreementName),
                ),
                Text(strings.agreementAnd),
                TextButton(
                  key: const ValueKey('login.userAgreementLink'),
                  style: linkStyle,
                  onPressed: enabled ? onOpenUserAgreement : null,
                  child: Text(strings.userAgreementName),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
