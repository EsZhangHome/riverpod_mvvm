// lib/features/home/view_model/home_view_model.dart
//
// 作用：首页 Notifier，负责首页数据加载和状态管理。
//
// 迁移说明（Provider → Riverpod）：
// - HomeViewModel extends BaseViewModel → HomeNotifier extends Notifier<HomeState>
// - asyncRequest → AsyncRequestHandler.execute
// - safeNotifyListeners → Riverpod 自动处理
// - locator → ref.read

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/base/base_view_model.dart';
import '../../../core/base/view_state.dart';
import '../../../core/providers/repositories.dart';
import '../model/home_banner.dart';

// ==================== 状态类 ====================

class HomeState {
  const HomeState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    this.banners = const [],
  });

  final ViewState viewState;
  final String errorMessage;
  final List<HomeBanner> banners;

  HomeState copyWith({
    ViewState? viewState,
    String? errorMessage,
    List<HomeBanner>? banners,
  }) {
    return HomeState(
      viewState: viewState ?? this.viewState,
      errorMessage: errorMessage ?? this.errorMessage,
      banners: banners ?? this.banners,
    );
  }
}

// ==================== Notifier ====================

class HomeNotifier extends Notifier<HomeState> {
  late final _handler = AsyncRequestHandler();

  @override
  HomeState build() {
    ref.onDispose(() => _handler.dispose());
    return const HomeState();
  }

  Future<void> loadHome() async {
    final banners = await _handler.execute<List<HomeBanner>>(
      request: () => ref.read(homeRepositoryProvider).fetchBanners(
            cancelToken: _handler.cancelToken,
          ),
      onLoading: () => state = state.copyWith(viewState: ViewState.loading),
      onSuccess: () => state = state.copyWith(viewState: ViewState.success),
      onEmpty: () => state = state.copyWith(viewState: ViewState.empty),
      onError: (msg) => state = state.copyWith(
        viewState: ViewState.error,
        errorMessage: msg,
      ),
      isEmpty: (data) => data.isEmpty,
    );
    if (banners != null) {
      state = state.copyWith(banners: banners);
    }
  }
}

// ==================== Provider ====================

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
