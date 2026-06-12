// lib/core/network/dio_interceptor.dart
//
// 作用：定义 Dio 的拦截器链，包括 Token 注入、日志打印、401 处理、网络重试。
//
// 拦截器链顺序（按添加顺序执行）：
// 1. TokenInterceptor     → 请求前自动注入 Authorization header
// 2. AppLogInterceptor     → 请求/响应/错误时打印日志
// 3. UnauthorizedInterceptor → 捕获 401 错误，通知 AuthProvider 退出登录
// 4. RetryInterceptor      → 超时/连接异常时自动重试
//
// 设计要点：
// - 拦截器之间通过责任链模式传递，每个拦截器处理完后调用 handler.next()
// - TokenInterceptor 每次请求前动态读取 token，避免登录/退出后需要重建 Dio
// - UnauthorizedGuard 防止多个并发 401 重复触发 logout
// - RetryInterceptor 只对超时和连接异常重试，不重试业务错误和 401

import 'package:dio/dio.dart';

import '../config/env_config.dart';
import '../utils/logger.dart';

// ==================== 1. Token 注入拦截器 ====================

/// 请求前自动注入 Authorization header。
///
/// 工作流程：
/// 1. 每次请求发出前，调用 tokenProvider 获取最新的 token
/// 2. 如果 token 不为空，设置 `Authorization: Bearer <token>`
/// 3. 调用 handler.next(options) 继续传递请求
///
/// 为什么使用动态读取而不是缓存：
/// - 登录后 token 会变化，需要动态读取
/// - 退出登录后 token 变为 null，需要立即反映到请求中
/// - 这样不需要在每次登录/退出后重新创建 Dio 实例
class TokenInterceptor extends Interceptor {
  TokenInterceptor({required this.tokenProvider});

  /// token 提供者，通常由 AuthProvider 注入。
  /// 返回 null 表示未登录，返回字符串表示当前 token。
  final String? Function() tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 动态读取最新 token，不缓存
    final token = tokenProvider();
    if (token != null && token.isNotEmpty) {
      // 设置 Authorization header，Bearer 是 OAuth 2.0 标准格式
      options.headers['Authorization'] = 'Bearer $token';
    }
    // 继续传递请求到下一个拦截器
    handler.next(options);
  }
}

// ==================== 2. 日志拦截器 ====================

/// 简单日志拦截器，仅在 debug 模式下打印请求和响应信息。
///
/// 打印内容：
/// - 请求：HTTP 方法和完整 URL
/// - 响应：HTTP 状态码和 URL
/// - 错误：HTTP 状态码和错误信息
///
/// 注意：不打印请求体和响应体，避免敏感信息泄露到日志中。
class AppLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 只打印方法和 URL，不打印 headers（含 token）和请求体（可能含密码）
    AppLogger.log('${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // 打印状态码和 URL，方便排查接口是否正常返回
    AppLogger.log(
      'Response ${response.statusCode}: ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 打印错误状态码和错误信息，方便排查网络问题
    AppLogger.log('Dio error ${err.response?.statusCode}: ${err.message}');
    handler.next(err);
  }
}

// ==================== 3. 401 防抖守卫 ====================

/// 401 并发保护器。
///
/// 问题场景：
/// 页面同时发出 3 个请求，这 3 个请求的 token 同时过期，
/// 后端对每个请求都返回 401。如果不做保护，会触发 3 次 logout，
/// 导致重复清空 token、重复跳转登录页等问题。
///
/// 解决方案：
/// 使用 _isHandling 标记，只有第一次 401 会触发 onUnauthorized 回调，
/// 后续的 401 会被忽略，直到 reset() 被调用（用户重新登录后）。
class UnauthorizedGuard {
  UnauthorizedGuard({required this.onUnauthorized});

  /// 401 时的回调，通常由 AuthProvider 注入，执行 logout 逻辑。
  final void Function() onUnauthorized;

  /// 是否正在处理 401，防止并发重复触发。
  bool _isHandling = false;

  /// 处理 401 事件。
  ///
  /// 如果 _isHandling 为 true，直接返回不做任何操作。
  /// 如果 _isHandling 为 false，设置为 true 并调用 onUnauthorized。
  void handle() {
    if (_isHandling) {
      // 已经处理过 401，跳过，避免重复 logout
      return;
    }
    _isHandling = true;
    onUnauthorized();
  }

  /// 重置 401 处理状态。
  ///
  /// 用户重新登录后调用，允许下一次 token 失效时再次响应 401。
  void reset() {
    _isHandling = false;
  }
}

// ==================== 4. 401 拦截器 ====================

/// 统一处理 401 未授权错误。
///
/// 工作流程：
/// 1. 捕获响应错误，检查 HTTP 状态码是否为 401
/// 2. 如果是 401，通过 UnauthorizedGuard 通知 AuthProvider 退出登录
/// 3. 无论是否 401，都调用 handler.next(err) 继续传递错误
///
/// 设计原则：
/// - 网络层只做"通知"，不直接操作路由或用户状态
/// - 真正的退出登录逻辑在 AuthProvider 中
/// - 401 错误仍然会继续传递，让调用方也能感知到错误
class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor({required this.guard});

  /// 401 防抖守卫，确保多个并发 401 只处理一次。
  final UnauthorizedGuard guard;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 检查 HTTP 状态码是否为 401
    if (err.response?.statusCode == 401) {
      // 通过 guard 通知 AuthProvider，内部有防抖保护
      guard.handle();
    }
    // 无论是否处理 401，都继续传递错误
    handler.next(err);
  }
}

// ==================== 5. 重试拦截器 ====================

/// 超时或连接异常自动重试拦截器。
///
/// 适用场景：弱网环境下偶发的超时或连接失败，通过重试提高成功率。
///
/// 不适用场景：
/// - 业务错误（4xx）：重试不会改变结果，不需要重试
/// - 服务器错误（5xx）：可能是服务器问题，重试可能加重服务器负担
/// - 请求取消：用户主动取消，不应该重试
///
/// 重试策略：
/// - 最多重试 retryCount 次（默认 2 次，可通过 EnvConfig 配置）
/// - 退避等待：第 1 次重试等 1 秒，第 2 次等 2 秒
/// - 使用 dio.fetch 复用原始 RequestOptions，保持参数不变
class RetryInterceptor extends Interceptor {
  RetryInterceptor({required this.dio, int? retryCount, List<int>? retryDelays})
    : retryCount = retryCount ?? EnvConfig.retryCount,
      retryDelays = retryDelays ?? const [1, 2];

  /// Dio 实例，用于重新发起请求。
  final Dio dio;

  /// 最大重试次数，超过后不再重试。
  final int retryCount;

  /// 重试退避延迟（秒），[1, 2] 表示第 1 次重试等 1 秒，第 2 次等 2 秒。
  final List<int> retryDelays;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // ---- 步骤 1：判断是否应该重试 ----
    // 只有超时和连接失败才重试，业务错误、401、取消等不重试
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    // ---- 步骤 2：检查重试次数 ----
    // retryIndex 存储在 requestOptions.extra 中，每次重试都会 +1
    final retryIndex = err.requestOptions.extra['retryIndex'] as int? ?? 0;
    if (retryIndex >= retryCount) {
      // 已达到最大重试次数，不再重试，继续传递错误
      handler.next(err);
      return;
    }

    // ---- 步骤 3：退避等待 ----
    // 根据重试次数选择对应的延迟时间
    // 如果 retryIndex 超出 retryDelays 长度，使用最后一个延迟值
    final delaySeconds =
        retryDelays[retryIndex < retryDelays.length
            ? retryIndex
            : retryDelays.length - 1];
    await Future<void>.delayed(Duration(seconds: delaySeconds));

    // ---- 步骤 4：更新重试计数并重新发起请求 ----
    err.requestOptions.extra['retryIndex'] = retryIndex + 1;
    try {
      // 使用 dio.fetch 复用原始 RequestOptions，保持所有参数不变
      final response = await dio.fetch<dynamic>(err.requestOptions);
      // 重试成功，返回响应
      handler.resolve(response);
    } on DioException catch (error) {
      // 重试失败，继续传递错误（RetryInterceptor 会再次捕获并判断是否继续重试）
      handler.next(error);
    }
  }

  /// 判断是否应该重试当前错误。
  ///
  /// 只重试网络层面的临时性错误：
  /// - connectionTimeout：连接超时
  /// - sendTimeout：发送超时
  /// - receiveTimeout：接收超时
  /// - connectionError：连接异常
  ///
  /// 不重试的错误：
  /// - badCertificate：证书问题，重试不会变
  /// - badResponse：服务器已返回错误，重试意义不大
  /// - cancel：用户主动取消
  /// - unknown：无法确定原因，不冒险重试
  bool _shouldRetry(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
