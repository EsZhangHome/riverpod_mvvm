// lib/core/base/view_state.dart
//
// 作用：定义页面在整个生命周期内可能出现的 5 种状态。
//
// 架构职责：
// - Notifier（ViewModel）通过更新 state.viewState 切换页面状态
// - StateView 负责根据状态切换 UI（loading/error/empty/idle/success）
// - 业务页面不需要关心状态切换逻辑，只需要在 builder 里写正常内容即可
//
// 状态流转说明：
// idle → loading → success / empty / error
// 任何状态都可以回到 idle 重置
// loading 状态下一般不会再次触发 loading（由 AsyncRequestHandler 防抖保证）
//
// 使用示例（Riverpod Notifier 模式）：
// ```dart
// class MyNotifier extends Notifier<MyState> {
//   late final _handler = AsyncRequestHandler();
//   Future<void> loadData() async {
//     await _handler.execute(
//       request: () => ref.read(repoProvider).fetchData(),
//       onLoading: () => state = state.copyWith(viewState: ViewState.loading),
//       onSuccess: () => state = state.copyWith(viewState: ViewState.success),
//       onError: (msg) => state = state.copyWith(viewState: ViewState.error, errorMessage: msg),
//     );
//   }
// }
// ```
enum ViewState {
  /// 初始空闲状态：页面刚创建，还没有开始任何请求。
  /// 此时 StateView 会直接展示 child（业务内容），适合展示默认页面布局。
  idle,

  /// 加载中状态：请求正在进行中。
  /// StateView 会根据 loadingStyle 决定展示方式：
  /// - replace 模式：用 LoadingView 替换整个内容区（适合列表首次加载）
  /// - overlay 模式：在内容上方叠加半透明遮罩（适合表单提交）
  loading,

  /// 成功状态：请求完成且数据不为空。
  /// StateView 会展示 child，即业务页面编写的正常内容。
  success,

  /// 空数据状态：请求成功但返回的数据为空（如列表长度为 0）。
  /// StateView 会展示 EmptyView，提示用户"暂无数据"。
  empty,

  /// 错误状态：请求失败，可能是网络异常、业务错误、超时等。
  /// StateView 会展示 ErrorView，显示 errorMessage 和可选的重试按钮。
  error,
}
