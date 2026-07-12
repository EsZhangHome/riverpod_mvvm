// lib/features/profile/view_model/profile_view_model.dart
//
// 作用：个人中心 Notifier，负责加载用户详细信息和维护页面状态。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/base/base_view_model.dart';
import '../../../core/base/view_state.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/repositories.dart';
import '../../../shared/models/user_model.dart';

// ==================== 状态类 ====================

class ProfileState {
  const ProfileState({
    this.viewState = ViewState.idle,
    this.errorMessage = '',
    this.user,
  });

  final ViewState viewState;
  final String errorMessage;
  final UserModel? user;

  ProfileState copyWith({
    ViewState? viewState,
    String? errorMessage,
    UserModel? user,
    bool clearUser = false,
  }) {
    return ProfileState(
      viewState: viewState ?? this.viewState,
      errorMessage: errorMessage ?? this.errorMessage,
      user: clearUser ? null : user ?? this.user,
    );
  }
}

// ==================== Notifier ====================

class ProfileNotifier extends Notifier<ProfileState> {
  late final _handler = AsyncRequestHandler();

  @override
  ProfileState build() {
    ref.onDispose(() => _handler.dispose());
    return const ProfileState();
  }

  Future<void> loadProfile(UserModel? currentUser) async {
    if (currentUser == null) {
      state = state.copyWith(
        viewState: ViewState.error,
        errorMessage: AppStrings.userMissing,
      );
      return;
    }

    final profile = await _handler.execute<UserModel>(
      request: () => ref
          .read(profileRepositoryProvider)
          .fetchProfile(currentUser, cancelToken: _handler.cancelToken),
      onLoading: () => state = state.copyWith(viewState: ViewState.loading),
      onSuccess: () => state = state.copyWith(viewState: ViewState.success),
      onError: (msg) =>
          state = state.copyWith(viewState: ViewState.error, errorMessage: msg),
    );

    if (ref.mounted && profile != null) {
      state = state.copyWith(user: profile);
    }
  }
}

// ==================== Provider ====================

final profileProvider =
    NotifierProvider.autoDispose<ProfileNotifier, ProfileState>(
      ProfileNotifier.new,
    );
