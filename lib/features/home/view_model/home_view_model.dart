// lib/features/home/view_model/home_view_model.dart
//
// 作用：首页 Notifier，负责首页数据加载和状态管理。
//
// 这是一个保留给未来 Banner 接口的完整网络生命周期示例：
// View 调用 loadHome -> Notifier 读取 Repository -> Repository 透传 CancelToken
// -> Handler 把结果转换为 ViewState -> View watch HomeState 重建。
//
// 建议阅读顺序：HomeState -> HomeNotifier.build -> loadHome -> homeProvider。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/async_request_handler.dart';
import '../../../shared/state/view_state.dart';
import '../home_providers.dart';
import '../model/home_banner.dart';

// ==================== 状态类 ====================

/// 首页 View 所需的不可变状态。
///
/// View 只消费这里的展示数据，不直接读取 Repository 或 Dio 响应。
class HomeState {
  const HomeState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    this.banners = const [],
  });

  /// 控制页面级 idle/loading/success/empty/error 展示。
  final ViewState viewState;

  /// 已转换为可展示内容的错误文案，不向 View 泄漏技术异常。
  final String errorMessage;

  /// 请求成功后的 Banner 列表；空列表与 empty 状态配合表达空页面。
  final List<HomeBanner> banners;

  HomeState copyWith({
    ViewState? viewState,
    String? errorMessage,
    List<HomeBanner>? banners,
  }) {
    // State 不原地修改。每次返回新对象，让 Riverpod 可以可靠通知监听者。
    return HomeState(
      viewState: viewState ?? this.viewState,
      errorMessage: errorMessage ?? this.errorMessage,
      banners: banners ?? this.banners,
    );
  }
}

// ==================== Notifier ====================

/// Banner 业务 ViewModel。
class HomeNotifier extends Notifier<HomeState> {
  // 一个 Provider 实例对应一个 Handler，取消令牌因此与页面订阅生命周期一致。
  late final _handler = AsyncRequestHandler();

  @override
  HomeState build() {
    // autoDispose 的最后一个监听者离开后，取消仍未结束的 Dio 请求。
    ref.onDispose(() => _handler.dispose());
    return const HomeState();
  }

  /// 加载首页 Banner，并把请求过程映射成 HomeState。
  Future<void> loadHome() async {
    final banners = await _handler.execute<List<HomeBanner>>(
      // 命令只需要一次 Repository 快照，所以使用 read，不建立响应式依赖。
      request: () => ref
          .read(homeRepositoryProvider)
          .fetchBanners(cancelToken: _handler.cancelToken),
      onLoading: () => state = state.copyWith(viewState: ViewState.loading),
      onSuccess: () => state = state.copyWith(viewState: ViewState.success),
      onEmpty: () => state = state.copyWith(viewState: ViewState.empty),
      onError: (msg) =>
          state = state.copyWith(viewState: ViewState.error, errorMessage: msg),
      isEmpty: (data) => data.isEmpty,
    );
    // await 期间页面可能已销毁。ref.mounted 防止向失效 Notifier 回写结果。
    if (ref.mounted && banners != null) {
      state = state.copyWith(banners: banners);
    }
  }
}

// ==================== Provider ====================

// Banner 页面离开后无需保留请求结果，autoDispose 同时触发请求取消。
final homeProvider = NotifierProvider.autoDispose<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
