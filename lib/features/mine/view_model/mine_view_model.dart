// lib/features/mine/view_model/mine_view_model.dart
//
// 作用：我的页 Notifier，负责"我的"Tab 的数据加载和状态管理。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/base/base_view_model.dart';
import '../../../core/base/view_state.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../shared/models/user_model.dart';

// ==================== 状态类 ====================

class MineState {
  const MineState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    this.user,
  });

  final ViewState viewState;
  final String errorMessage;
  final UserModel? user;

  MineState copyWith({
    ViewState? viewState,
    String? errorMessage,
    UserModel? user,
    bool clearUser = false,
  }) {
    return MineState(
      viewState: viewState ?? this.viewState,
      errorMessage: errorMessage ?? this.errorMessage,
      user: clearUser ? null : user ?? this.user,
    );
  }
}

// ==================== Notifier ====================

class MineNotifier extends AutoDisposeNotifier<MineState> {
  late final _handler = AsyncRequestHandler();

  @override
  MineState build() {
    ref.onDispose(() => _handler.dispose());
    return const MineState();
  }

  Future<void> loadMine(UserModel? currentUser) async {
    if (currentUser == null) {
      state = state.copyWith(
        viewState: ViewState.error,
        errorMessage: AppStrings.userMissing,
      );
      return;
    }

    final loadedUser = await _handler.execute<UserModel>(
      request: () async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return currentUser;
      },
      onLoading: () => state = state.copyWith(viewState: ViewState.loading),
      onSuccess: () => state = state.copyWith(viewState: ViewState.success),
      onError: (msg) =>
          state = state.copyWith(viewState: ViewState.error, errorMessage: msg),
    );

    if (loadedUser != null) {
      state = state.copyWith(user: loadedUser);
    }
  }
}

// ==================== Provider ====================

final mineProvider = AutoDisposeNotifierProvider<MineNotifier, MineState>(
  MineNotifier.new,
);
