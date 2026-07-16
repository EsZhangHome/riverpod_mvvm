// lib/shared/ui/state_view.dart
//
// 作用：根据 ViewState 自动切换展示 loading、error、empty 或真实内容。
//
// 这是整个 MVVM 架构中 View 层和 ViewModel 层的连接点。
// 业务页面不需要自己判断 viewState，只需要在 StateView 的 child 中写正常内容。
//
// 状态展示规则：
// - idle/success → 展示 child（业务页面内容）
// - loading + replace → 展示 LoadingView（替换整个内容区）
// - loading + overlay → 在 child 上叠加半透明遮罩
// - error → 展示 ErrorView（含错误信息和重试按钮）
// - empty → 展示 EmptyView（提示暂无数据）
//
// 使用方式：
// ```dart
// StateView(
//   state: viewModel.viewState,
//   errorMessage: viewModel.errorMessage,
//   onRetry: () => viewModel.loadData(),
//   loadingStyle: LoadingStyle.replace,
//   child: ListView(...), // 正常内容
// );
// ```

import 'package:flutter/material.dart';

import '../state/view_state.dart';
import '../localization/user_message.dart';
import 'empty_view.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// loading 展示方式。
///
/// 和 StateView 放在同一文件，避免 PageShell 与 StateView 互相导入。
enum LoadingStyle {
  /// 用 LoadingView 替换整个内容区域。
  replace,

  /// 在原内容上方叠加半透明 loading 遮罩。
  overlay,
}

/// 根据 ViewState 自动选择展示 loading、error、empty 或真实内容。
///
/// 业务页面只需要提供 child（正常内容），其他状态由 StateView 统一处理。
/// 这样所有页面的 loading/error/empty 样式保持一致，不需要在每个页面中重复写。
class StateView extends StatelessWidget {
  /// 创建统一状态展示组件。
  ///
  /// - [state]：ViewModel 当前 ViewState；
  /// - [child]：idle/success 时展示的真实业务内容，overlay loading 时也保留在底层；
  /// - [errorMessage]：error 状态交给 ErrorView 的安全文案；
  /// - [onRetry]：可选重试操作，为 null 时错误页不显示按钮；
  /// - [loadingStyle]：replace 完全替换内容，overlay 保留内容并阻挡交互；
  /// - [key]：可选 Widget 身份键。
  ///
  /// 本组件只负责“状态 → UI”的映射，不主动更改 Provider，也不会自动发起首次加载。
  const StateView({
    super.key,
    required this.state,
    required this.child,
    this.errorMessage,
    this.onRetry,
    this.loadingStyle = LoadingStyle.replace,
  });

  /// 当前页面状态（来自 ViewModel）。
  final ViewState state;

  /// 正常内容（业务页面编写的 UI）。
  final Widget child;

  /// 错误提示文案，仅在 error 状态下展示。
  final UserMessage? errorMessage;

  /// 重试回调，为 null 时 ErrorView 不显示重试按钮。
  final VoidCallback? onRetry;

  /// loading 展示方式，默认为 replace（替换整个内容区）。
  final LoadingStyle loadingStyle;

  @override
  Widget build(BuildContext context) {
    // 根据 ViewState 决定展示哪种 UI
    switch (state) {
      // ==================== loading 状态 ====================
      case ViewState.loading:
        if (loadingStyle == LoadingStyle.overlay) {
          // overlay 模式：保留原页面内容，同时盖一层半透明 loading
          // 使用 Stack 实现叠加效果
          // 适合登录、提交表单等不希望页面内容消失的场景
          return Stack(
            children: [
              // 底层：原页面内容
              child,
              // 顶层：半透明遮罩 + 加载动画
              Container(
                // 半透明黑色遮罩，让用户知道页面正在处理中
                color: Colors.black12,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        // replace 模式：用 LoadingView 替换整个内容区
        // 适合列表页首次加载，用户体验更清爽
        return const LoadingView();

      // ==================== error 状态 ====================
      case ViewState.error:
        // 展示错误页，onRetry 不为空时显示重试按钮
        return ErrorView(message: errorMessage, onRetry: onRetry);

      // ==================== empty 状态 ====================
      case ViewState.empty:
        // 展示空数据页，提示用户"暂无数据"
        return const EmptyView();

      // ==================== idle / success 状态 ====================
      case ViewState.idle:
      case ViewState.success:
        // idle 和 success 都展示真实内容
        // idle 常用于页面刚创建但还没开始请求的瞬间
        return child;
    }
  }
}
