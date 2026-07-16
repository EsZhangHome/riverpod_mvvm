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
//     // await 期间 Provider 可能已销毁，回写 State 前仍需检查 ref.mounted。
//     if (ref.mounted && banners != null) {
//       state = state.copyWith(banners: banners);
//     }
//   }
// }
// ```

import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_observer.dart';
import '../../core/network/request_cancellation.dart';
import '../errors/failure_message_resolver.dart';
import '../localization/user_message.dart';

/// 异步请求处理器，封装了 ViewModel 常用的请求管理逻辑。
///
/// 提供的能力：
/// 1. 请求互斥：同一时间只允许一个请求（_isRequesting），重复调用直接忽略
/// 2. 取消令牌管理：dispose 时取消当前 Handler 发出的请求
/// 3. 状态切换回调：通过 onLoading/onSuccess/onEmpty/onError 委托给 Notifier
///
/// 每个 ViewModel Notifier 在 build() 中创建一个实例，
/// 并在 ref.onDispose 中调用 dispose() 取消请求。
class AsyncRequestHandler {
  /// 创建一个只管理“一条请求通道”的处理器。
  ///
  /// 一个 Handler 同时只执行一个 request，适合登录、保存、首次加载等互斥命令。
  /// 同一 ViewModel 若有两个可以并行的独立操作，应分别创建两个 Handler；不要为了
  /// 复用而让互不相关的请求互相阻塞。
  AsyncRequestHandler();

  // ==================== 私有状态 ====================

  /// 是否正在执行请求（互斥标记）。
  bool _isRequesting = false;

  /// Handler 是否已经结束生命周期；结束后 execute 永远返回 null。
  bool _isDisposed = false;

  // ==================== 公开属性 ====================

  /// 取消令牌，生命周期与 Notifier 绑定。
  ///
  /// 使用方式：Repository 继续把它传给 ApiService，不需要知道底层是否使用 Dio。
  /// dispose 时自动 cancel；ApiClient 会把信号适配为具体网络库的 IO 取消操作。
  final RequestCancellationToken cancelToken = RequestCancellationToken();

  // ==================== 核心方法 ====================

  /// 统一包装异步请求，自动处理请求互斥、状态切换、异常转换。
  ///
  /// [request]：真正的异步请求闭包（通常是调用 Repository 的方法）
  ///
  /// [onLoading]：请求开始时调用，通常设置 state.viewState = loading
  /// [onSuccess]：请求成功且有数据时调用
  /// [onEmpty]：请求成功但数据为空时调用；只有同时传 [isEmpty] 才可能触发
  /// [onError]：请求失败时调用，message 是安全且等待 View 本地化的类型化消息
  ///
  /// [isEmpty]：判断数据是否为空的回调，如 (data) => data.isEmpty
  ///
  /// 返回值：成功时返回数据，失败/重复调用/取消/销毁时返回 null。
  ///
  /// 重要边界：
  /// - 如果 [isEmpty] 返回 true 但 [onEmpty] 没传，方法仍返回 data，只是不执行
  ///   onSuccess；因此使用空状态判断时应配套提供 onEmpty；
  /// - onLoading/onSuccess/onEmpty/onError 都是同步回调，通常只更新 Notifier.state，
  ///   不要在里面再次发起未等待的异步操作；
  /// - T 本身若允许 null，`T?` 返回值无法区分“成功得到 null”和“请求未执行/失败”，
  ///   这种业务应把结果包装成明确 Model，而不要把 T 定义为可空类型。
  Future<T?> execute<T>({
    required Future<T> Function() request,
    required void Function() onLoading,
    required void Function(UserMessage message) onError,
    required void Function() onSuccess,
    void Function()? onEmpty,
    bool Function(T data)? isEmpty,
  }) async {
    // ---- 步骤 1：请求互斥检查 ----
    if (_isRequesting || _isDisposed) {
      return null;
    }

    // ---- 步骤 2：取消令牌检查 ----
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
    } catch (error, stackTrace) {
      // ---- 步骤 6：错误处理 ----
      if (_isDisposed ||
          cancelToken.isCancelled ||
          (error is AppFailure && error.isCancellation)) {
        return null;
      }
      // FailureObserver 会忽略网络/业务等预期失败，同时上报协议、存储、未知异常的
      // 原始 cause/stack。页面无论是否上报都只得到安全类型化文案。
      FailureObserver.reportIfNeeded(error, stackTrace);
      onError(FailureMessageResolver.resolve(error));
      return null;
    } finally {
      // ---- 步骤 7：释放互斥标记 ----
      _isRequesting = false;
    }
  }

  // ==================== 生命周期 ====================

  /// 释放资源，取消所有使用此 token 的 Dio 请求。
  ///
  /// 可重复调用；只有第一次真正取消。调用后 Handler 不可复用，一般在 Notifier.build
  /// 中通过 `ref.onDispose(_handler.dispose)` 注册，不能等 Widget 自己手工清理。
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('handler disposed');
    }
  }
}
