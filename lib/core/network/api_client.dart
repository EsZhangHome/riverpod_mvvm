// lib/core/network/api_client.dart
//
// 作用：ApiService 接口的具体实现，封装 Dio 实例，提供统一的 HTTP 请求方法。
//
// 架构职责：
// - 实现 ApiService 接口，提供常用 HTTP、上传与下载能力
// - 管理 Dio 实例的创建和配置（baseUrl、超时、headers）
// - 构造一次稳定拦截器链，运行时只更新认证回调
// - 处理请求结果的统一解析和异常转换
// - 通过回调接收 token、刷新和 401 处理，不反向依赖认证模块
//
// 设计要点：
// 1. 容器托管：ApiClient 由 Riverpod Provider 创建、持有和释放
// 2. 回调注入：authNetworkBindingProvider 在组合层接线，网络层不 import 认证模块
// 3. 统一解析：_request 方法统一处理 API 响应解析和异常转换
// 4. 拦截器链稳定：token 或 401 回调变化不会清空正在执行的拦截器链
// 5. Charles 抓包：通过 EnvConfig 开关控制，默认关闭，不影响正常请求
//
// 数据流：
// Repository → ApiClient.get/post/... → _request → Dio 请求 → 拦截器链 → 后端
//                                                  ↓
//                                          解析响应 / 转换异常
//                                                  ↓
//                                         ApiResponse<T> / throw exception

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../config/env_config.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'api_service.dart';
import 'dio_interceptor.dart';
import 'network_quality_monitor.dart';
import 'request_context.dart';
import 'response_adapter.dart';
import 'token_refresh_coordinator.dart';

/// ApiClient 是网络请求的统一入口。
///
/// Repository 只依赖 ApiService 接口，不直接依赖 ApiClient。
/// Riverpod 通过 apiClientProvider 创建实例，再由 apiServiceProvider
/// 以 ApiService 接口类型交给 Repository；测试可 override 任一层。
///
/// 使用方式：
/// ```dart
/// // Repository 构造函数只接收抽象接口。
/// class HomeRepositoryImpl implements HomeRepository {
///   final ApiService _apiService;
///   HomeRepositoryImpl(this._apiService);
/// }
/// ```
class ApiClient implements ApiService {
  /// 创建网络客户端，并在创建时安装底座统一的拦截器链。
  ///
  /// 参数说明：
  /// - [dio]：可选的 Dio 实例。正式运行通常不传，由底座根据 [EnvConfig]
  ///   创建并配置 baseUrl、连接/收发超时和 JSON Header；单元测试或接入已有
  ///   网络配置时可以传入。传入的 Dio 仍会被本类安装代理配置和拦截器，调用
  ///   [close] 时也会被关闭，因此不要把同一个 Dio 同时交给其他长期对象持有；
  /// - [responseAdapter]：把后端响应体转换成 `ApiResponse<T>` 的协议适配器。
  ///   不传时使用 [EnvelopeResponseAdapter]，即默认后端协议是
  ///   `{code, message, data}`。真实项目协议不同时，应在 Provider 组合层替换，
  ///   不要在每个 Repository 内重复拆响应字段。
  ///
  /// 构造函数只负责创建基础设施，不会立即发起网络请求。调用方应让 Riverpod
  /// 托管本实例，并在 Provider 销毁时调用 [close] 释放连接池。
  /// - [networkQualityMonitor]：可选真实请求质量监控器。由 Provider 传入后，
  ///   ApiClient 只负责上报耗时/传输失败，不直接显示全局提示。
  ApiClient({
    Dio? dio,
    ResponseAdapter? responseAdapter,
    this.networkQualityMonitor,
  }) : _responseAdapter = responseAdapter ?? const EnvelopeResponseAdapter() {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            // 从 EnvConfig 读取 baseUrl，通过 --dart-define 切换环境
            baseUrl: EnvConfig.apiBaseUrl,
            // 连接超时：建立 TCP 连接的最大等待时间
            connectTimeout: const Duration(seconds: EnvConfig.connectTimeout),
            // 接收超时：等待服务器返回响应的最大时间
            receiveTimeout: const Duration(seconds: EnvConfig.receiveTimeout),
            // 发送超时：发送请求体的最大等待时间
            sendTimeout: const Duration(seconds: EnvConfig.sendTimeout),
            // 默认 Content-Type，大多数接口都是 JSON
            headers: {'Content-Type': 'application/json'},
          ),
        );
    // 如果编译参数打开了 Charles 抓包，这里给 Dio 换上带代理的 HttpClient。
    _configureCharlesProxyIfNeeded();
    // 拦截器链只创建一次。登录、退出和刷新 Token 只更新回调字段，避免请求执行中
    // 清空 Dio interceptors。
    _unauthorizedGuard = UnauthorizedGuard(
      onUnauthorized: () async {
        await _onUnauthorized?.call();
      },
    );
    _configureInterceptors();
  }

  // ==================== 私有字段 ====================

  /// Dio 实例由 ApiClient 统一维护。
  ///
  /// 普通 Repository 应通过 ApiService 请求，不应读取下面的 [dio] getter；getter
  /// 只为基础设施扩展和底层测试保留，因此这里不是“完全隐藏 Dio”的强隔离。
  late final Dio _dio;

  /// 当前项目使用的响应协议适配器。
  ///
  /// 它在客户端创建后保持不变，确保同一个 ApiClient 的所有 Repository 遵循
  /// 同一套成功码、消息字段和 data 解码规则。若项目存在多套完全不同的后端协议，
  /// 应按服务域创建不同 ApiClient，而不是在单个请求中临时切换协议。
  final ResponseAdapter _responseAdapter;

  /// 可选的请求质量采样边界。null 表示调用方不需要弱网质量判断。
  final NetworkQualityMonitor? networkQualityMonitor;

  /// token 提供者回调，由认证网络组合 Provider 注入。
  ///
  /// 每次请求前，TokenInterceptor 会调用这个回调获取最新 token。
  /// 返回 null 表示未登录，返回字符串表示当前 token。
  String? Function()? _tokenProvider;

  /// 401 未授权回调，由认证网络组合 Provider 注入。
  ///
  /// 当刷新不可用、刷新失败或重放后仍为 401，确认会话失效时调用该回调。
  Future<void> Function()? _onUnauthorized;

  /// 刷新访问令牌的可选回调。
  ///
  /// 返回新的非空 token 表示刷新成功；返回 null/空字符串或抛出异常表示刷新失败。
  /// 多个并发 401 会由 [TokenRefreshCoordinator] 合并为一次刷新操作。
  RefreshAccessToken? _refreshAccessToken;

  /// 会话失效守卫，防止一批 401 重复触发退出登录。
  late final UnauthorizedGuard _unauthorizedGuard;

  // ==================== 公开属性 ====================

  /// 底层 Dio 扩展入口，例如项目组合层添加签名、缓存或监控拦截器。
  ///
  /// 业务 Repository 不应使用它直接调用 `dio.get/post`，否则会绕过本类统一的
  /// 响应协议适配和异常转换。读取此 getter 不会创建新对象，返回的就是本类持有的
  /// Dio；对其 options/interceptors 的修改会影响之后的全部请求。
  Dio get dio => _dio;

  // ==================== Charles 抓包配置 ====================

  /// 根据 EnvConfig 决定是否给 Dio 配置 Charles 代理。
  ///
  /// 这里没有写死 true/false，而是读取编译参数：
  /// - 默认 false：正常网络请求，不走 Charles
  /// - 打开 true：所有 Dio 请求都会转发到 Charles，方便查看请求和响应
  ///
  /// 注意：这个能力只用于 Android/iOS 调试。项目已经只保留移动端平台，
  /// 因此可以直接使用 dart:io 的 HttpClient。
  void _configureCharlesProxyIfNeeded() {
    if (!EnvConfig.enableCharlesProxy) {
      return;
    }

    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();

        // 告诉底层 HttpClient：请求不要直接发给目标服务器，
        // 而是先转发到 Charles 的 host:port。
        client.findProxy = (uri) {
          return 'PROXY ${EnvConfig.charlesProxyHost}:'
              '${EnvConfig.charlesProxyPort}';
        };

        // HTTPS 抓包需要证书信任。优先推荐在设备上安装并信任 Charles 根证书。
        // 如果只是临时调试证书问题，可以用 dart-define 打开这个开关。
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              return EnvConfig.allowCharlesBadCertificate;
            };

        return client;
      },
    );
  }

  // ==================== 回调注入方法 ====================

  /// 设置 token 提供者回调。
  ///
  /// 由认证网络组合 Provider 调用。拦截器通过闭包读取当前回调，因此这里只替换
  /// 字段，不会在请求执行期间清空或重建 Dio 拦截器链。
  ///
  /// [tokenProvider] 会在“每一次请求真正发送前”被调用，而不是在这里立即读取。
  /// 回调应只读取内存中的认证状态，不要在回调内访问数据库或发起异步请求；未登录
  /// 时返回 null/空字符串，请求就不会携带 Authorization Header。
  void setTokenProvider(String? Function() tokenProvider) {
    _tokenProvider = tokenProvider;
  }

  /// 设置确认会话失效后的处理回调。
  ///
  /// 由认证网络组合 Provider 调用。UnauthorizedGuard 和拦截器在客户端构造时已
  /// 创建，这里只更新它们稍后读取的业务回调。
  ///
  /// [callback] 通常清理 SessionStore，让路由守卫自动跳回登录页。它只在刷新不可用
  /// 或最终失败后调用，不应在这里直接操作某个页面的 BuildContext。
  void setUnauthorizedCallback(Future<void> Function() callback) {
    _onUnauthorized = callback;
  }

  /// 设置可选的 token 刷新回调。
  ///
  /// [callback] 接收不到参数，因为刷新所需的 refresh token 应由认证模块自己持有；
  /// 成功时返回新的 access token，失败时返回 null/空字符串或抛异常。传 null 表示
  /// 当前项目不支持静默刷新，遇到 401 后直接走会话失效流程。
  void setTokenRefreshCallback(RefreshAccessToken? callback) {
    _refreshAccessToken = callback;
  }

  /// 重置会话失效守卫。
  ///
  /// 用户重新登录或成功恢复会话后，由认证网络组合 Provider 调用。
  /// 允许下一次 token 失效时再次响应 401。
  void resetUnauthorizedGuard() {
    _unauthorizedGuard.reset();
  }

  // ==================== HTTP 方法实现 ====================

  /// GET 请求：通常用于获取列表、详情等读取类接口。
  ///
  /// 示例：
  /// ```dart
  /// final response = await apiClient.get<List<Map<String, dynamic>>>(
  ///   '/products',
  ///   fromJson: (json) => (json as List)
  ///       .map((item) => Map<String, dynamic>.from(item as Map))
  ///       .toList(),
  /// );
  /// ```
  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  }) {
    return _request<T>(
      // 传入闭包，延迟执行，_request 内部统一处理异常和解析
      () => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _options(context),
      ),
      fromJson,
    );
  }

  /// POST 请求：通常用于登录、创建资源、提交表单等写入类接口。
  ///
  /// 示例：
  /// ```dart
  /// final response = await apiClient.post<Map<String, dynamic>>(
  ///   '/auth/login',
  ///   data: {'account': 'xxx', 'password': 'xxx'},
  ///   fromJson: (json) => Map<String, dynamic>.from(json as Map),
  /// );
  /// ```
  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  }) {
    return _request<T>(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _options(context),
      ),
      fromJson,
    );
  }

  /// PUT 请求：通常用于完整更新资源。
  ///
  /// HTTP 语义上 PUT 应设计为幂等，但是否能安全重试仍取决于后端实现和
  /// RequestContext，客户端不会只凭 PUT 方法名自动重试。
  @override
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  }) {
    return _request<T>(
      () => _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _options(context),
      ),
      fromJson,
    );
  }

  /// PATCH 请求：通常只更新资源的部分字段。
  ///
  /// 参数含义与 [post] 相同。PATCH 默认不允许网络自动重试；只有后端已实现幂等
  /// 语义时，调用方才能通过 [RequestContext] 显式开启。
  @override
  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  }) {
    return _request<T>(
      () => _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _options(context),
      ),
      fromJson,
    );
  }

  /// DELETE 请求：通常用于删除资源。
  ///
  /// 保留 data 和 queryParameters 参数以兼容不同后端风格。
  @override
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  }) {
    return _request<T>(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _options(context),
      ),
      fromJson,
    );
  }

  /// 文件上传请求：用于上传头像、附件、图片等。
  ///
  /// 内部将文件路径和额外字段组装成 FormData。
  ///
  /// 示例：
  /// ```dart
  /// final response = await apiClient.upload<UploadResult>(
  ///   '/upload/avatar',
  ///   filePath: '/path/to/avatar.jpg',
  ///   fileField: 'avatar',
  ///   onSendProgress: (sent, total) => print('${sent/total*100}%'),
  /// );
  /// ```
  @override
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required String filePath,
    String fileField = 'file',
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  }) async {
    // 组装 FormData：把普通字段和文件字段合并
    final formData = FormData.fromMap({
      // 展开额外字段（如用户 ID、描述等）
      ...?data,
      // 文件字段，默认字段名为 'file'，可通过 fileField 自定义
      fileField: await MultipartFile.fromFile(filePath),
    });
    return _request<T>(
      // 上传使用 POST 方法，data 为 FormData
      () => _dio.post<dynamic>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
        options: _options(context, forceNeverReplay: true),
      ),
      fromJson,
    );
  }

  @override
  Future<void> download(
    String path,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    RequestContext? context,
  }) async {
    try {
      await _dio.download(
        path,
        savePath,
        queryParameters: queryParameters,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        options: _options(context, forceNeverReplay: true),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  // ==================== 核心请求方法 ====================

  /// 统一请求处理：发出请求 → 解析响应 → 异常转换。
  ///
  /// `get/post/put/patch/delete/upload` 最终都调用这个方法；
  /// `download` 返回文件而不是业务响应，因此单独处理。
  ///
  /// 处理流程：
  /// 1. 执行 [request] 闭包发出 HTTP 请求。
  /// 2. 交给项目注入的 [ResponseAdapter] 适配响应协议并生成 `ApiResponse<T>`。
  /// 3. 根据适配结果判断业务是否成功；失败时抛出 `BusinessException`。
  /// 4. 把 Dio 网络异常转换为稳定的 `ApiException`，避免上层依赖 Dio 错误枚举。
  /// 5. 把模型解码或协议不匹配转换为协议错误，交给上层统一生成安全提示文案。
  ///
  /// 参数说明：
  /// - [request]：真正执行 Dio 请求的异步闭包。使用闭包可让所有 HTTP 方法共用
  ///   同一套成功判断、异常边界和响应解析流程；
  /// - [fromJson]：把响应协议中 data 字段转换成 T。返回类型复杂时必须提供；
  ///   如果转换函数本身抛错，会被归类为响应协议/解码错误，而不是网络断开。
  ///
  /// 返回值是已经过协议适配和业务成功码校验的 `ApiResponse<T>`。业务码失败会抛
  /// [BusinessException]，Dio 错误会抛稳定的 [ApiException]；调用方无需识别
  /// `DioExceptionType`。
  Future<ApiResponse<T>> _request<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic json)? fromJson,
  ) async {
    try {
      // ---- 步骤 1：执行 HTTP 请求 ----
      final response = await request();
      final apiResponse = _responseAdapter.adapt<T>(response, fromJson);
      if (!apiResponse.isSuccess) {
        throw BusinessException(
          code: apiResponse.code,
          userMessage: apiResponse.message,
          canDisplayMessage: apiResponse.canDisplayMessage,
        );
      }
      return apiResponse;
    } on DioException catch (error) {
      // ---- 步骤 4：网络异常转换 ----
      // 把 Dio 的异常转为 ApiException，ViewModel 不需要知道 Dio 的错误枚举
      throw ApiException.fromDioException(error);
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      // decoder/协议不匹配不属于网络失败，转成稳定的协议错误交给上层解析。
      throw ApiException(
        code: ApiException.unknownError,
        message: 'Response decoding failed: $error',
      );
    }
  }

  /// 把与业务无关的 [RequestContext] 转成 Dio 的单次请求配置。
  ///
  /// [context] 为 null 且 [forceNeverReplay] 为 false 时返回 null，表示完全沿用 Dio
  /// 默认 Options。context.headers 会进入真实 HTTP Header；requestId、allowRetry
  /// 等客户端控制信息会进入 extra，供拦截器读取，不会自动发送给服务器。
  ///
  /// [forceNeverReplay] 用于上传、下载等流式请求。即使调用方误传了允许重放的
  /// context，也会强制写入 `replayDisabled`，避免文件流被 401/弱网重试重复消费。
  Options? _options(RequestContext? context, {bool forceNeverReplay = false}) {
    if (context == null && !forceNeverReplay) return null;
    return Options(
      headers: {
        ...?context?.headers,
        if (context?.idempotencyKey != null)
          'Idempotency-Key': context!.idempotencyKey,
      },
      extra: {
        ...?context?.extra,
        if (context?.requestId != null) 'requestId': context!.requestId,
        if (context?.allowRetry ?? false) 'allowRetry': true,
        if (forceNeverReplay || context?.trackNetworkQuality == false)
          'networkQualityExcluded': true,
        if (forceNeverReplay ||
            context?.replayPolicy == RequestReplayPolicy.never)
          'replayDisabled': true,
      },
    );
  }

  /// 释放 Dio 持有的连接池并取消尚未结束的请求。
  ///
  /// `force: true` 表示不等待存量连接自然结束，适合 ProviderContainer/应用会话真正
  /// 销毁时调用。关闭后本实例不可再次请求。若构造时注入了外部 Dio，它也会被关闭，
  /// 这就是构造函数要求“不要共享外部 Dio 所有权”的原因。
  void close() => _dio.close(force: true);

  // ==================== 拦截器管理 ====================

  /// 创建稳定拦截器链，只在 ApiClient 构造时调用一次。
  ///
  /// 调用时机只有 ApiClient 初始化。回调变化由闭包动态读取。
  ///
  /// 拦截器按下面的顺序添加：
  /// 1. RequestMetadataInterceptor → 补充请求 ID
  /// 2. TokenInterceptor           → 请求前动态注入 Authorization header
  /// 3. AppLogInterceptor          → 向当前 LogSink 记录脱敏元数据
  /// 4. NetworkQualityInterceptor  → 采集真实请求耗时与传输失败
  /// 5. UnauthorizedInterceptor    → 捕获 401，并尝试刷新与安全重放
  /// 6. RetryInterceptor           → 按白名单重试临时网络错误
  void _configureInterceptors() {
    // 0. 请求追踪标识。
    _dio.interceptors.add(RequestMetadataInterceptor());

    // 1. Token 注入（每次请求前动态读取 token）
    _dio.interceptors.add(
      TokenInterceptor(tokenProvider: () => _tokenProvider?.call()),
    );

    // 2. 脱敏网络日志。是否真正输出由 AppLogger 当前配置的 LogSink 决定。
    _dio.interceptors.add(AppLogInterceptor());

    // 3. 网络质量采样是可选能力；未注入 Monitor 时完全不安装，也不产生额外对象。
    final qualityMonitor = networkQualityMonitor;
    if (qualityMonitor != null) {
      _dio.interceptors.add(NetworkQualityInterceptor(monitor: qualityMonitor));
    }

    // 4. 401 处理。闭包在真正发生 401 时读取最新刷新回调，不需要重建拦截器。
    _dio.interceptors.add(
      UnauthorizedInterceptor(
        guard: _unauthorizedGuard,
        dio: _dio,
        refreshAccessToken: () async {
          final callback = _refreshAccessToken;
          return callback == null ? null : callback();
        },
      ),
    );

    // 5. 网络重试：默认只重试 GET/HEAD 的临时连接错误；写请求必须显式声明幂等。
    _dio.interceptors.add(RetryInterceptor(dio: _dio));
  }
}
