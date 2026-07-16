// lib/shared/state/async_request_handler.dart
//
// 作用：提供 Notifier 常用的请求防重复、取消和状态回调能力。
//
// 使用方式：
// ```dart
// class HomeNotifier extends Notifier<HomeState> {
//   late final _handler = AsyncRequestHandler();
//
//   @override
//   HomeState build() {
//     ref.onDispose(() => _handler.dispose());
//     return const HomeState();
//   }
//
//   Future<void> loadHome() async {
//     final banners = await _handler.execute<List<HomeBanner>>(
//       request: () => ref.read(homeRepositoryProvider).fetchBanners(
//         cancelToken: _handler.cancelToken,
//       ),
//       onLoading: () => state = state.copyWith(viewState: ViewState.loading),
//       onSuccess: () => state = state.copyWith(viewState: ViewState.success),
//       onEmpty: () => state = state.copyWith(viewState: ViewState.empty),
//       onError: (msg) => state = state.copyWith(
//         viewState: ViewState.error,
//         errorMessage: msg,
//       ),
//       isEmpty: (data) => data.isEmpty,
//     );
//     if (banners != null) {
//       state = state.copyWith(banners: banners);
//     }
//   }
// }
// ```

import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';

/// 异步请求处理器，封装了 ViewModel 常用的请求管理逻辑。
///
/// 提供的能力：
/// 1. 请求防抖：同一时间只允许一个请求（_isRequesting）
/// 2. CancelToken 管理：dispose 时自动取消所有请求
/// 3. 状态切换回调：通过 onLoading/onSuccess/onEmpty/onError 委托给 Notifier
///
/// 每个 ViewModel Notifier 在 build() 中创建一个实例，
/// 并在 ref.onDispose 中调用 dispose() 取消请求。
class AsyncRequestHandler {
  // ==================== 私有状态 ====================

  /// 是否正在执行请求（防抖标记）。
  bool _isRequesting = false;
  bool _isDisposed = false;

  // ==================== 公开属性 ====================

  /// 取消令牌，生命周期与 Notifier 绑定。
  ///
  /// 使用方式：Repository 调用 Dio 时透传此 token。
  /// dispose 时自动 cancel，Dio 会抛出 CancelException。
  final CancelToken cancelToken = CancelToken();

  // ==================== 核心方法 ====================

  /// 统一包装异步请求，自动处理防抖、状态切换、异常转换。
  ///
  /// [request]：真正的异步请求闭包（通常是调用 Repository 的方法）
  ///
  /// [onLoading]：请求开始时调用，通常设置 state.viewState = loading
  /// [onSuccess]：请求成功且有数据时调用
  /// [onEmpty]：请求成功但数据为空时调用（不传则走 onSuccess）
  /// [onError]：请求失败时调用，message 已转换为对用户友好的文案
  ///
  /// [isEmpty]：判断数据是否为空的回调，如 (data) => data.isEmpty
  ///
  /// 返回值：成功时返回数据，失败/防抖/取消时返回 null
  Future<T?> execute<T>({
    required Future<T> Function() request,
    required void Function() onLoading,
    required void Function(String message) onError,
    required void Function() onSuccess,
    void Function()? onEmpty,
    bool Function(T data)? isEmpty,
  }) async {
    // ---- 步骤 1：请求防抖检查 ----
    if (_isRequesting || _isDisposed) {
      return null;
    }

    // ---- 步骤 2：CancelToken 检查 ----
    if (cancelToken.isCancelled) {
      return null;
    }

    try {
      // ---- 步骤 3：标记请求中 + 切换 loading 状态 ----
      _isRequesting = true;
      onLoading();

      // ---- 步骤 4：执行真正的异步请求 ----
      final data = await request();

      // Provider 可能在 await 期间被释放。此时丢弃结果，禁止回写状态。
      if (_isDisposed || cancelToken.isCancelled) {
        return null;
      }

      // ---- 步骤 5：根据结果判断 success 还是 empty ----
      if (isEmpty != null && isEmpty(data)) {
        onEmpty?.call();
      } else {
        onSuccess();
      }
      return data;
    } catch (error) {
      // ---- 步骤 6：错误处理 ----
      if (_isDisposed ||
          cancelToken.isCancelled ||
          (error is ApiException && error.isCancelled)) {
        return null;
      }
      if (error is BusinessException) {
        onError(error.userMessage);
      } else if (error is ApiException) {
        onError(error.message);
      } else {
        onError('请求失败，请稍后重试');
      }
      return null;
    } finally {
      // ---- 步骤 7：释放防抖标记 ----
      _isRequesting = false;
    }
  }

  // ==================== 生命周期 ====================

  /// 释放资源，取消所有使用此 token 的 Dio 请求。
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('handler disposed');
    }
  }
}
