// lib/core/network/dio_interceptor.dart
//
// 作用：定义 Dio 的拦截器链，包括 Token 注入、日志打印、401 处理、网络重试。
//
// 拦截器链顺序（按添加顺序执行）：
// 1. RequestMetadataInterceptor → 补齐 requestId
// 2. TokenInterceptor           → 请求前自动注入 Authorization header
// 3. AppLogInterceptor          → 请求/响应/错误时记录脱敏日志
// 4. NetworkQualityInterceptor → 用真实请求样本判断弱网，不额外发送探测请求
// 5. UnauthorizedInterceptor   → 捕获 401，协调刷新、重放或通知会话失效
// 6. RetryInterceptor          → 超时/连接异常时按安全规则重试
//
// 设计要点：
// - 拦截器之间通过责任链模式传递，每个拦截器处理完后调用 handler.next()
// - TokenInterceptor 每次请求前动态读取 token，避免登录/退出后需要重建 Dio
// - UnauthorizedGuard 防止多个并发 401 重复触发 logout
// - RetryInterceptor 只对超时和连接异常重试，不重试业务错误和 401

import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../config/env_config.dart';
import '../performance/performance_reporter.dart';
import '../utils/logger.dart';
import 'network_quality_monitor.dart';
import 'token_refresh_coordinator.dart';

// ==================== 0. 请求追踪 ====================

/// 为每次请求补齐可追踪的 requestId。
///
/// Repository 已通过 RequestContext 提供 id 时原样透传；没有时在客户端生成。
/// 同一个 id 同时放进 Header 和 Dio extra：服务端能串联日志，客户端拦截器也能读取。
class RequestMetadataInterceptor extends Interceptor {
  /// 进程内递增序号，与微秒时间戳组合以降低同一时刻请求 ID 冲突概率。
  ///
  /// 这不是跨设备全局唯一 UUID。若公司网关要求特定 trace-id 格式，应由调用方在
  /// `RequestContext.requestId` 中传入，拦截器会尊重该值而不覆盖。
  static int _sequence = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final supplied = options.extra['requestId']?.toString();
    final requestId = supplied?.isNotEmpty == true
        ? supplied!
        : '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    // putIfAbsent 尊重调用方显式提供的 X-Request-Id，不在基础设施层悄悄覆盖。
    options.extra['requestId'] = requestId;
    options.extra['requestStartedMicros'] = developer.Timeline.now;
    options.headers.putIfAbsent('X-Request-Id', () => requestId);
    handler.next(options);
  }
}

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
  /// 创建 Token 注入拦截器。
  ///
  /// [tokenProvider] 是同步回调，每次请求发送前执行一次。使用回调而不是直接传
  /// token，是为了让同一个 Dio 在登录、刷新和退出后都能读取到最新认证状态。
  TokenInterceptor({required this.tokenProvider});

  /// token 提供者，由上层组合代码注入；拦截器不知道具体认证状态实现。
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

/// 脱敏网络日志拦截器，把记录交给当前配置的 AppLogger。
///
/// 打印内容：
/// - 请求：HTTP 方法、服务地址和路径（不含用户信息、Query、Fragment）
/// - 响应：HTTP 状态码和安全路径
/// - 错误：Dio 错误类型、HTTP 状态码和安全路径
///
/// 注意：不打印请求体和响应体，避免敏感信息泄露到日志中。
class AppLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 只打印方法和 URL，不打印 headers（含 token）和请求体（可能含密码）
    AppLogger.info(
      '${options.method} ${_safeUri(options.uri)}',
      context: {'requestId': options.extra['requestId']},
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _recordTiming(response.requestOptions, response.statusCode);
    // 打印状态码和 URL，方便排查接口是否正常返回
    AppLogger.info(
      'Response ${response.statusCode}: '
      '${_safeUri(response.requestOptions.uri)}',
      context: {'requestId': response.requestOptions.extra['requestId']},
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _recordTiming(err.requestOptions, err.response?.statusCode);
    // 不附加原始 DioException：它可能间接包含 Header、请求体或响应体。
    AppLogger.warning(
      'Dio ${err.type.name} ${err.response?.statusCode ?? '-'}: '
      '${_safeUri(err.requestOptions.uri)}',
      context: {
        'requestId': err.requestOptions.extra['requestId'],
        'errorType': err.type.name,
        'statusCode': err.response?.statusCode,
      },
    );
    handler.next(err);
  }

  /// Query 和 fragment 经常包含搜索词、手机号或业务编号，日志只保留服务地址和路径。
  String _safeUri(Uri uri) {
    if (!uri.hasScheme) return uri.path;
    // 手工重建是为了同时排除 userInfo。直接打印 Uri 可能泄露 Basic Auth，
    // replace(query: '') 还会留下无意义的 ?#，影响日志检索聚合。
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://$host$port${uri.path}';
  }

  void _recordTiming(RequestOptions request, int? statusCode) {
    final started = request.extra['requestStartedMicros'];
    if (started is! int) return;
    final elapsedMicros = developer.Timeline.now - started;
    if (elapsedMicros < 0) return;
    AppPerformance.record(
      'network.request',
      Duration(microseconds: elapsedMicros),
      attributes: {
        'method': request.method,
        'path': request.uri.path,
        'statusCode': statusCode,
        'retryIndex': request.extra['retryIndex'] ?? 0,
      },
    );
  }
}

// ==================== 3. 网络质量采样 ====================

/// 把真实接口耗时和明确的传输失败交给 [NetworkQualityMonitor]。
///
/// 本拦截器只采样，不展示 Toast，也不读取 Riverpod。这样网络层仍然不知道 Widget，
/// UI 层可通过 Provider 监听 Monitor 事件后决定是否提示用户。
class NetworkQualityInterceptor extends Interceptor {
  /// 创建质量采样拦截器；[monitor] 与 ApiClient 处于同一个 ProviderContainer。
  NetworkQualityInterceptor({required this.monitor});

  /// 接收样本并维护弱网状态的纯 Dart 服务。
  final NetworkQualityMonitor monitor;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.requestOptions.extra['networkQualityExcluded'] == true) {
      handler.next(response);
      return;
    }
    final elapsed = _elapsedSinceRequest(response.requestOptions);
    if (elapsed != null) monitor.recordSuccess(elapsed);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.extra['networkQualityExcluded'] == true) {
      handler.next(err);
      return;
    }
    // 采用白名单，只把网络传输阶段的失败算作弱网。用户取消、业务响应、证书问题
    // 或未知编程异常不会触发全局网络提示。
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        monitor.recordTransportFailure();
        break;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        break;
      // Dio 新版本可能增加 transformTimeout 等类型。弱网判断必须采用明确白名单，
      // 未知的新类型默认忽略，不能在升级依赖后自动变成“网络差”误报。
      // 根项目当前锁定版本已穷举全部枚举，因此分析器会认为 default 暂时不可达；
      // 独立 Demo 可解析到更新的兼容版本，这个分支会负责向前兼容。
      // ignore: unreachable_switch_default
      default:
        break;
    }
    handler.next(err);
  }

  Duration? _elapsedSinceRequest(RequestOptions request) {
    final started = request.extra['requestStartedMicros'];
    if (started is! int) return null;
    final elapsedMicros = developer.Timeline.now - started;
    if (elapsedMicros < 0) return null;
    return Duration(microseconds: elapsedMicros);
  }
}

// ==================== 4. 401 会话失效去重守卫 ====================

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
  /// 创建并发 401 去重守卫。
  ///
  /// [onUnauthorized] 只负责“会话确定失效后的业务处理”，通常是清除本地会话；
  /// 不要在基础设施回调中保存页面 BuildContext 或直接 push 登录页，路由应通过
  /// 监听认证状态自行重定向。
  UnauthorizedGuard({required this.onUnauthorized});

  /// 会话确定失效时的回调，通常由组合层绑定退出登录命令。
  final Future<void> Function() onUnauthorized;

  /// 是否正在处理 401，防止并发重复触发。
  bool _isHandling = false;

  /// 处理 401 事件。
  ///
  /// 如果 _isHandling 为 true，直接返回不做任何操作。
  /// 如果 _isHandling 为 false，设置为 true 并调用 onUnauthorized。
  ///
  /// 注意：回调执行失败后 `_isHandling` 仍保持 true，目的是避免同一批失败请求形成
  /// 退出风暴；恢复会话或重新登录后必须由组合层显式调用 [reset]。
  Future<void> handle() async {
    if (_isHandling) {
      // 已经处理过 401，跳过，避免重复 logout
      return;
    }
    _isHandling = true;
    try {
      await onUnauthorized();
    } catch (error) {
      AppLogger.log('Unauthorized handling failed: $error');
    }
  }

  /// 重置 401 处理状态。
  ///
  /// 用户重新登录或成功恢复会话后调用，允许下一次失效再次响应 401。
  void reset() {
    _isHandling = false;
  }
}

// ==================== 5. 401 拦截器 ====================

/// 统一处理 401 未授权错误。
///
/// 工作流程：
/// 1. 非 401 直接传递；
/// 2. 首次 401 尝试共享的 Token 刷新；
/// 3. 刷新成功且请求允许重放时，只重放一次；
/// 4. 未配置刷新、刷新失败或重放后仍为 401 时，通过 Guard 通知会话失效；
/// 5. replayDisabled 请求即使刷新成功也不自动重放，原 401 交给调用方处理。
///
/// 设计原则：
/// - 网络层只做"通知"，不直接操作路由或用户状态
/// - 真正的退出登录逻辑由上层回调实现，网络层不 import 认证模块
/// - 只有重放成功时 resolve 响应，其余 401 继续传递给调用方
class UnauthorizedInterceptor extends Interceptor {
  /// 创建 401 刷新与安全重放拦截器。
  ///
  /// 参数说明：
  /// - [guard]：并发会话失效去重器，确保一批 401 只清理一次会话；
  /// - [dio]：用于通过 `dio.fetch` 重放原请求的同一个 Dio 实例；
  /// - [refreshAccessToken]：可选刷新函数。成功返回新 token，不支持刷新时传 null；
  /// - [refreshCoordinator]：合并并发刷新操作的协调器。生产通常不传，测试可以注入
  ///   独立实例验证并发行为。
  UnauthorizedInterceptor({
    required this.guard,
    required this.dio,
    this.refreshAccessToken,
    TokenRefreshCoordinator? refreshCoordinator,
  }) : refreshCoordinator = refreshCoordinator ?? TokenRefreshCoordinator();

  /// 会话失效守卫，确保一批 401 只触发一次退出处理。
  final UnauthorizedGuard guard;

  /// 发送原请求重放的客户端。必须与触发当前拦截器的 Dio 为同一实例，才能保留
  /// baseUrl、适配器、超时和完整拦截器链。
  final Dio dio;

  /// 刷新访问令牌的可选回调；null 表示直接把 401 视为会话失效。
  final RefreshAccessToken? refreshAccessToken;

  /// 并发刷新协调器：刷新进行中时，后续 401 复用同一个 Future。
  final TokenRefreshCoordinator refreshCoordinator;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final request = err.requestOptions;
    if (request.extra['authRetried'] == true || refreshAccessToken == null) {
      await guard.handle();
      handler.next(err);
      return;
    }

    try {
      final token = await refreshCoordinator.run(refreshAccessToken!);
      if (token == null || token.isEmpty) {
        await guard.handle();
        handler.next(err);
        return;
      }

      if (request.extra['replayDisabled'] == true) {
        // Token 已刷新，可供下一次手动请求使用；当前流式或敏感请求不自动重放。
        handler.next(err);
        return;
      }

      request.extra['authRetried'] = true;
      request.headers['Authorization'] = 'Bearer $token';
      final response = await dio.fetch<dynamic>(request);
      handler.resolve(response);
    } on Object catch (error) {
      // 刷新异常可能携带 Header、响应体等隐私数据，只记录异常类型用于聚合。
      AppLogger.warning(
        'Token refresh failed',
        context: {'errorType': error.runtimeType.toString()},
      );
      await guard.handle();
      handler.next(err);
    }
  }
}

// ==================== 6. 重试拦截器 ====================

/// 对满足幂等条件的超时或连接异常执行有限重试。
///
/// 适用场景：弱网环境下 GET/HEAD 偶发超时或连接失败；其他方法只有在调用方
/// 确认服务端支持幂等并设置 `RequestContext.allowRetry` 后才允许重试。
///
/// 不适用场景：
/// - HTTP 客户端错误（4xx）：重复发送通常不会改变结果
/// - 服务器错误（5xx）：可能是服务器问题，重试可能加重服务器负担
/// - 请求取消：用户主动取消，不应该重试
///
/// 重试策略：
/// - 最多重试 retryCount 次（默认 2 次，可通过 EnvConfig 配置）
/// - 退避等待：第 1 次重试等 1 秒，第 2 次等 2 秒
/// - 使用 dio.fetch 复用原始 RequestOptions，保持参数不变
/// - replayDisabled 请求不参与重试
class RetryInterceptor extends Interceptor {
  /// 创建临时网络错误重试拦截器。
  ///
  /// 参数说明：
  /// - [dio]：用于重放原始 RequestOptions 的同一个 Dio 实例；
  /// - [retryCount]：最多“额外尝试”的次数，不包含第一次请求。null 时读取
  ///   [EnvConfig.retryCount]，0 表示完全不重试；
  /// - [retryDelays]：每次重试前等待的秒数。列表不能空；重试次数超过列表长度时
  ///   会重复使用最后一个值，例如 `[1, 2]` 且重试 4 次时依次等待 1、2、2、2 秒。
  RetryInterceptor({required this.dio, int? retryCount, List<int>? retryDelays})
    : retryCount = retryCount ?? EnvConfig.retryCount,
      retryDelays = retryDelays ?? const [1, 2] {
    if (this.retryDelays.isEmpty) {
      throw ArgumentError.value(retryDelays, 'retryDelays', '不能为空');
    }
  }

  /// Dio 实例，用于重新发起请求。
  final Dio dio;

  /// 最大额外重试次数，第一次正常请求不计入该数字。
  ///
  /// 负数没有业务意义，项目配置应保持大于等于 0；当前实现会把负数等价为不重试。
  final int retryCount;

  /// 重试退避延迟（秒），[1, 2] 表示第 1 次重试等 1 秒，第 2 次等 2 秒。
  final List<int> retryDelays;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // ---- 步骤 1：判断是否应该重试 ----
    // 除了错误类型，还会检查请求方法、幂等声明与 replayDisabled 标记。
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

    // 页面可能在退避等待期间销毁，取消后不再发起重试。
    if (err.requestOptions.cancelToken?.isCancelled ?? false) {
      handler.next(err);
      return;
    }

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
    if (err.requestOptions.extra['replayDisabled'] == true) return false;
    const retryableMethods = {'GET', 'HEAD'};
    final explicitlyRetryable = err.requestOptions.extra['allowRetry'] == true;
    if (!retryableMethods.contains(err.requestOptions.method.toUpperCase()) &&
        !explicitlyRetryable) {
      return false;
    }

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
      // 新增异常类型默认不重试。自动重放请求必须采用白名单，而不是把未来
      // 未知错误当成临时网络问题，尤其要避免非幂等写请求被重复发送。
      // ignore: unreachable_switch_default
      default:
        return false;
    }
  }
}
