// lib/features/profile/view_model/profile_view_model.dart
//
// 作用：个人中心 Notifier，负责加载用户详细信息和维护页面状态。
//
// 执行顺序：校验当前用户 -> Handler 发请求 -> ViewState 切换
// -> await 后检查 ref.mounted -> 保存 UserModel。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/base/async_request_handler.dart';
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

  /// 详情加载成功前为 null，View 可以暂时回退显示 AuthState 基础用户。
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
  // 与 autoDispose Provider 同生命周期，集中管理 CancelToken。
  late final _handler = AsyncRequestHandler();

  @override
  ProfileState build() {
    // 页面最后一个监听者离开时取消仍在执行的详情请求。
    ref.onDispose(() => _handler.dispose());
    return const ProfileState();
  }

  Future<void> loadProfile(UserModel? currentUser) async {
    // 没有当前用户说明会话不完整，不应向 Repository 发请求。
    if (currentUser == null) {
      state = state.copyWith(
        viewState: ViewState.error,
        errorMessage: AppStrings.userMissing,
      );
      return;
    }

    // Handler 将请求开始/成功/失败映射为不可变 ProfileState。
    final profile = await _handler.execute<UserModel>(
      request: () => ref
          .read(profileRepositoryProvider)
          .fetchProfile(currentUser, cancelToken: _handler.cancelToken),
      onLoading: () => state = state.copyWith(viewState: ViewState.loading),
      onSuccess: () => state = state.copyWith(viewState: ViewState.success),
      onError: (msg) =>
          state = state.copyWith(viewState: ViewState.error, errorMessage: msg),
    );

    // await 后 Provider 可能销毁；mounted 是最后一道状态回写保护。
    if (ref.mounted && profile != null) {
      state = state.copyWith(user: profile);
    }
  }
}

// ==================== Provider ====================

// 独立资料页离开后无需保留详情，使用 autoDispose。
final profileProvider =
    NotifierProvider.autoDispose<ProfileNotifier, ProfileState>(
      ProfileNotifier.new,
    );
