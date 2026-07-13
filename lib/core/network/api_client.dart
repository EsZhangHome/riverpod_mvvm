// lib/core/network/api_client.dart
//
// 作用：ApiService 接口的具体实现，封装 Dio 实例，提供统一的 HTTP 请求方法。
//
// 架构职责：
// - 实现 ApiService 接口，提供 get/post/put/delete/upload 五个方法
// - 管理 Dio 实例的创建和配置（baseUrl、超时、headers）
// - 管理拦截器链的组装和更新
// - 处理请求结果的统一解析和异常转换
// - 通过回调注入 token 和 401 处理，解耦网络层和 AuthProvider
//
// 设计要点：
// 1. 单例模式：整个 App 只有一个 ApiClient 实例（通过 ApiClient.instance 获取）
// 2. 回调注入：tokenProvider 和 onUnauthorized 由 AuthProvider 注入，网络层不依赖任何业务层
// 3. 统一解析：_request 方法统一处理 API 响应解析和异常转换
// 4. 拦截器动态更新：token 或 401 回调变更时，重新组装拦截器链
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
import 'endpoints.dart';

/// ApiClient 是网络请求的统一入口。
///
/// Repository 只依赖 ApiService 接口，不直接依赖 ApiClient。
/// Riverpod 在 services.dart 中把 ApiClient.instance 暴露为 apiClientProvider，
/// 再由 apiServiceProvider 以 ApiService 接口类型交给 Repository。
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
  // ==================== 单例模式 ====================

  /// 私有构造函数，在构造时完成 Dio 实例的初始化和拦截器组装。
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        // 从 EnvConfig 读取 baseUrl，通过 --dart-define 切换环境
        baseUrl: Endpoints.baseUrl,
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
    // 组装拦截器链
    _resetInterceptors();
  }

  /// 全局唯一实例。
  static final ApiClient instance = ApiClient._internal();

  // ==================== 私有字段 ====================

  /// Dio 实例，只在 ApiClient 内部维护，外部不可见。
  ///
  /// 外部如果要请求接口，应通过 ApiService 接口的 get/post/put/delete/upload 方法，
  /// 而不是直接使用 dio。
  late final Dio _dio;

  /// token 提供者回调，由 AuthProvider 注入。
  ///
  /// 每次请求前，TokenInterceptor 会调用这个回调获取最新 token。
  /// 返回 null 表示未登录，返回字符串表示当前 token。
  String? Function()? _tokenProvider;

  /// 401 未授权回调，由 AuthProvider 注入。
  ///
  /// 当拦截器捕获到 401 错误时，调用这个回调执行退出登录。
  Future<void> Function()? _onUnauthorized;

  /// 401 防抖守卫，防止多个并发 401 重复触发退出登录。
  UnauthorizedGuard? _unauthorizedGuard;

  // ==================== 公开属性 ====================

  /// 暴露 Dio 实例，仅供特殊场景使用（如自定义拦截器）。
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
  /// 由 AuthProvider 在构造时调用。
  /// 设置后会重新组装拦截器链，确保 TokenInterceptor 使用最新的 tokenProvider。
  void setTokenProvider(String? Function() tokenProvider) {
    _tokenProvider = tokenProvider;
    _resetInterceptors();
  }

  /// 设置 401 未授权回调。
  ///
  /// 由 AuthProvider 在构造时调用。
  /// 设置后会创建 UnauthorizedGuard 和 UnauthorizedInterceptor，
  /// 并重新组装拦截器链。
  void setUnauthorizedCallback(Future<void> Function() callback) {
    _onUnauthorized = callback;
    _unauthorizedGuard = UnauthorizedGuard(onUnauthorized: callback);
    _resetInterceptors();
  }

  /// 重置 401 防抖守卫。
  ///
  /// 用户重新登录后，由 AuthProvider 调用。
  /// 允许下一次 token 失效时再次响应 401。
  void resetUnauthorizedGuard() {
    _unauthorizedGuard?.reset();
  }

  // ==================== HTTP 方法实现 ====================

  /// GET 请求：通常用于获取列表、详情等读取类接口。
  ///
  /// 示例：
  /// ```dart
  /// final response = await apiClient.get<List<HomeBanner>>(
  ///   Endpoints.homeBanners,
  ///   fromJson: (json) => (json as List).map((e) => HomeBanner.fromJson(e)).toList(),
  /// );
  /// ```
  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    T Function(dynamic json)? fromJson,
  }) {
    return _request<T>(
      // 传入闭包，延迟执行，_request 内部统一处理异常和解析
      () => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
      fromJson,
    );
  }

  /// POST 请求：通常用于登录、创建资源、提交表单等写入类接口。
  ///
  /// 示例：
  /// ```dart
  /// final response = await apiClient.post<LoginResponse>(
  ///   Endpoints.login,
  ///   data: {'account': 'xxx', 'password': 'xxx'},
  ///   fromJson: (json) => LoginResponse.fromJson(json),
  /// );
  /// ```
  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    T Function(dynamic json)? fromJson,
  }) {
    return _request<T>(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
      fromJson,
    );
  }

  /// PUT 请求：通常用于完整更新资源。
  ///
  /// 与 POST 的区别：PUT 是幂等的，多次调用结果相同。
  @override
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    T Function(dynamic json)? fromJson,
  }) {
    return _request<T>(
      () => _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
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
    T Function(dynamic json)? fromJson,
  }) {
    return _request<T>(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
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
      ),
      fromJson,
    );
  }

  // ==================== 核心请求方法 ====================

  /// 统一请求处理：发出请求 → 解析响应 → 异常转换。
  ///
  /// 所有 HTTP 方法（get/post/put/delete/upload）最终都调用这个方法。
  ///
  /// 处理流程：
  /// 1. 执行 request() 闭包发出 HTTP 请求
  /// 2. 检查响应数据是否为标准 Map 格式
  ///    - 是：按 `ApiResponse<T>` 解析，检查业务 code 是否成功
  ///    - 否：兼容处理，直接包装为 ApiResponse
  /// 3. 捕获 DioException，转换为 ApiException 抛出
  ///
  /// [request]：HTTP 请求闭包，由各方法传入
  /// [fromJson]：将原始 JSON 转为业务 Model 的回调
  Future<ApiResponse<T>> _request<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic json)? fromJson,
  ) async {
    try {
      // ---- 步骤 1：执行 HTTP 请求 ----
      final response = await request();
      final data = response.data;

      // ---- 步骤 2：解析响应数据 ----
      // 如果后端返回标准 Map 格式（{code, message, data}），按 ApiResponse 解析
      if (data is Map<String, dynamic>) {
        final apiResponse = ApiResponse<T>.fromJson(data, fromJson);
        // 检查业务 code 是否成功
        if (!apiResponse.isSuccess) {
          // 业务 code 失败（如账号冻结、余额不足），抛出 BusinessException
          throw BusinessException(
            code: apiResponse.code,
            userMessage: apiResponse.message,
          );
        }
        return apiResponse;
      }

      // ---- 步骤 3：兼容非标准格式 ----
      // 有些接口可能直接返回数组或字符串（如某些旧接口）
      // 这种情况下包装为 ApiResponse，code 使用 HTTP 状态码
      return ApiResponse<T>(
        code: response.statusCode ?? 200,
        message: response.statusMessage ?? 'success',
        // fromJson 为空时直接把 data 当作 T 类型
        data: fromJson == null ? data as T? : fromJson(data),
      );
    } on DioException catch (error) {
      // ---- 步骤 4：异常转换 ----
      // 把 Dio 的异常转为 ApiException，ViewModel 不需要知道 Dio 的错误枚举
      throw ApiException.fromDioException(error);
    }
  }

  // ==================== 拦截器管理 ====================

  /// 重新组装拦截器链。
  ///
  /// 调用时机：
  /// - ApiClient 初始化时
  /// - setTokenProvider 被调用时（token 提供者变了）
  /// - setUnauthorizedCallback 被调用时（401 回调变了）
  ///
  /// 拦截器顺序（重要，按添加顺序执行）：
  /// 1. TokenInterceptor     → 请求前自动注入 Authorization header
  /// 2. AppLogInterceptor     → 打印请求/响应日志
  /// 3. UnauthorizedInterceptor → 捕获 401 错误（仅在设置了 onUnauthorized 时添加）
  /// 4. RetryInterceptor      → 超时/连接异常时自动重试（放在最后，捕获前面传下来的错误）
  void _resetInterceptors() {
    // 清除所有旧拦截器
    _dio.interceptors.clear();

    // 1. Token 注入（每次请求前动态读取 token）
    _dio.interceptors.add(
      TokenInterceptor(tokenProvider: () => _tokenProvider?.call()),
    );

    // 2. 日志打印（debug 模式下打印请求/响应信息）
    _dio.interceptors.add(AppLogInterceptor());

    // 3. 401 处理（仅在设置了回调时添加）
    if (_onUnauthorized != null) {
      // 确保 _unauthorizedGuard 已创建
      _unauthorizedGuard ??= UnauthorizedGuard(
        onUnauthorized: _onUnauthorized!,
      );
      _dio.interceptors.add(
        UnauthorizedInterceptor(guard: _unauthorizedGuard!),
      );
    }

    // 4. 网络重试（放在最后，可以捕获前面所有拦截器传下来的网络错误）
    _dio.interceptors.add(RetryInterceptor(dio: _dio));
  }
}
