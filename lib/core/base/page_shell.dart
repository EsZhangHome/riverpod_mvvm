// lib/core/base/page_shell.dart
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

import '../../shared/widgets/state_view.dart';
import 'view_state.dart';

/// loading 展示方式枚举。
enum LoadingStyle {
  /// 替换模式：用 LoadingView 替换整个内容区域。
  replace,

  /// 叠加模式：在原内容上方叠加半透明 loading 遮罩。
  overlay,
}

/// 页面内容构建函数类型。
typedef PageContentBuilder = Widget Function(BuildContext context);

/// 精简的页面外壳：统一处理 StateView 包装。
///
/// 不处理 ViewModel 创建（由 NotifierProvider 管理），
/// 不处理状态监听（由外部 ConsumerStatefulWidget 的 ref.watch 完成）。
///
/// 适用场景：需要统一 StateView 状态切换的页面。
/// 复杂页面（如带表单、需要管理 TextEditingController）直接用 ConsumerStatefulWidget。
class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.viewState,
    required this.builder,
    this.errorMessage = '',
    this.onRetry,
    this.loadingStyle = LoadingStyle.replace,
  });

  /// 当前页面状态（来自 Notifier 的 state.viewState）
  final ViewState viewState;

  /// 正常内容构建器
  final PageContentBuilder builder;

  /// 错误提示文案
  final String errorMessage;

  /// 重试回调（ErrorView 点击重试按钮时调用）
  final VoidCallback? onRetry;

  /// loading 展示方式，默认 replace
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
