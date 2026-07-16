// lib/core/network/token_refresh_coordinator.dart
//
// 页面常会并发请求多个接口。Token 过期时它们会同时返回 401；如果每个请求
// 都刷新一次，会造成 refresh storm，甚至让后端把前一次新 token 立即作废。
// Coordinator 用“正在执行的 Future”作为单航班锁，所有请求等待同一结果。

typedef RefreshAccessToken = Future<String?> Function();

/// 合并同一时刻发生的多个 Token 刷新请求。
///
/// 它不是互斥锁，也不保存用户会话；只在刷新进行期间保存那一个 Future。
/// 刷新完成后立即清空，下一次 Token 真正过期时仍可再次执行。
class TokenRefreshCoordinator {
  /// 非 null 表示刷新正在进行。这里缓存 Future，不缓存 token 本身。
  Future<String?>? _inFlight;

  /// 执行或加入当前刷新任务。并发调用者会拿到完全相同的 Future 结果。
  Future<String?> run(RefreshAccessToken refresh) {
    final active = _inFlight;
    // 后来的 401 直接等待第一次刷新，不再调用 refresh。
    if (active != null) return active;

    // Future.sync 同时接住同步抛错与异步抛错，所有等待者看到同一结果。
    final future = Future<String?>.sync(refresh);
    _inFlight = future;
    return future.whenComplete(() {
      // 成功和失败都必须清锁，下一次真正过期时才能重新刷新。
      // identical 防止旧 Future 的完成回调误清除未来可能替换的新任务。
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }
}
