// lib/features/community/view_model/community_view_model.dart
//
// 作用：社区页 Notifier，负责社区数据加载和状态管理。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/base/base_view_model.dart';
import '../../../core/base/view_state.dart';

// ==================== 状态类 ====================

class CommunityState {
  const CommunityState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    this.posts = const [],
  });

  final ViewState viewState;
  final String errorMessage;
  final List<String> posts;

  CommunityState copyWith({
    ViewState? viewState,
    String? errorMessage,
    List<String>? posts,
  }) {
    return CommunityState(
      viewState: viewState ?? this.viewState,
      errorMessage: errorMessage ?? this.errorMessage,
      posts: posts ?? this.posts,
    );
  }
}

// ==================== Notifier ====================

class CommunityNotifier extends Notifier<CommunityState> {
  late final _handler = AsyncRequestHandler();

  @override
  CommunityState build() {
    ref.onDispose(() => _handler.dispose());
    return const CommunityState();
  }

  Future<void> loadCommunity() async {
    final posts = await _handler.execute<List<String>>(
      request: () async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return const [
          'Provider 如何做依赖注入？',
          'MVVM 中 ViewModel 应该写什么？',
          'Dio 拦截器的 token 刷新实践',
        ];
      },
      onLoading: () => state = state.copyWith(viewState: ViewState.loading),
      onSuccess: () => state = state.copyWith(viewState: ViewState.success),
      onEmpty: () => state = state.copyWith(viewState: ViewState.empty),
      onError: (msg) =>
          state = state.copyWith(viewState: ViewState.error, errorMessage: msg),
      isEmpty: (data) => data.isEmpty,
    );

    if (ref.mounted && posts != null) {
      state = state.copyWith(posts: posts);
    }
  }
}

// ==================== Provider ====================

final communityProvider =
    NotifierProvider.autoDispose<CommunityNotifier, CommunityState>(
      CommunityNotifier.new,
    );
