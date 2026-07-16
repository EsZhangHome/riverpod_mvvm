// lib/shared/ui/page_shell.dart
//
// 作用：通用页面展示容器，根据 ViewState 选择内容、加载、空和错误视图。
//
// 使用方式：
// ```dart
// class HomePage extends ConsumerStatefulWidget {
//   @override
//   ConsumerState<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends ConsumerState<HomePage> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) ref.read(homeProvider.notifier).loadHome();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final state = ref.watch(homeProvider);
//     return PageShell(
//       viewState: state.viewState,
//       errorMessage: state.errorMessage,
//       onRetry: () => ref.read(homeProvider.notifier).loadHome(),
//       builder: (context) => Scaffold(body: ListView(...)),
//     );
//   }
// }
// ```
//
// PageShell 只是减省 StateView 的样板封装。复杂的页面（如 LoginPage 带表单）
// 可以直接使用 ConsumerStatefulWidget + StateView，不需要 PageShell。

import 'package:flutter/material.dart';

import '../state/view_state.dart';
import 'state_view.dart';

/// 页面正常内容构建函数类型。
///
/// [context] 是 PageShell 当前所在位置的 BuildContext，可读取 Theme/MediaQuery；
/// 返回值一般是 Scaffold 或页面主体。它不是 ViewModel 构造函数，也不接收 Ref。
typedef PageContentBuilder = Widget Function(BuildContext context);

/// 精简的页面外壳：统一处理 StateView 包装。
///
/// 不处理 ViewModel 创建（由 NotifierProvider 管理），
/// 不处理状态监听（由外部 ConsumerStatefulWidget 的 ref.watch 完成）。
///
/// 适用场景：需要统一 StateView 状态切换的页面。
/// 复杂页面（如带表单、需要管理 TextEditingController）直接用 ConsumerStatefulWidget。
class PageShell extends StatelessWidget {
  /// 创建带统一状态切换能力的页面外壳。
  ///
  /// 参数说明：
  /// - [viewState]：ViewModel 输出的页面阶段；
  /// - [builder]：idle/success 或 overlay 底层显示的正常页面；
  /// - [errorMessage]：error 状态下的安全提示；
  /// - [onRetry]：可选重试命令，null 时错误页没有按钮；
  /// - [loadingStyle]：首次加载通常 replace，表单提交通常 overlay；
  /// - [key]：可选 Widget 身份键。
  ///
  /// 即使 replace loading/error/empty 当前不会显示正常内容，`builder(context)` 仍会在
  /// build 时执行后作为 child 传给 StateView。因此 builder 应只构建 Widget，不要在
  /// 里面发请求或执行副作用。
  const PageShell({
    super.key,
    required this.viewState,
    required this.builder,
    this.errorMessage = '',
    this.onRetry,
    this.loadingStyle = LoadingStyle.replace,
  });

  /// 当前页面状态（来自 Notifier 的 state.viewState）。
  final ViewState viewState;

  /// 正常内容构建器。
  final PageContentBuilder builder;

  /// 错误提示文案，仅 error 状态使用。
  final String errorMessage;

  /// 重试回调（ErrorView 点击重试按钮时调用）。
  final VoidCallback? onRetry;

  /// loading 展示方式，默认 replace。
  final LoadingStyle loadingStyle;

  @override
  Widget build(BuildContext context) {
    return StateView(
      state: viewState,
      errorMessage: errorMessage,
      onRetry: onRetry,
      loadingStyle: loadingStyle,
      child: builder(context),
    );
  }
}
