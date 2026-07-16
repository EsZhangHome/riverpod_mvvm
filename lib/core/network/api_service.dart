// lib/core/network/api_service.dart
//
// 作用：定义网络服务的抽象接口，Repository 层依赖此接口而非具体实现。
//
// 架构职责：
// - 定义所有 HTTP 方法的签名（get/post/put/patch/delete/upload/download）
// - 让 Repository 依赖抽象而非具体实现（依赖倒置原则）
// - 测试时可以用 FakeApiService 替换真实的 ApiClient
//
// 设计要点：
// 1. 每个方法都支持泛型 <T>，通过 fromJson 回调把原始 JSON 转成业务 Model
// 2. 每个方法都支持 CancelToken，ViewModel 可把它绑定到 Provider 生命周期
// 3. 数据请求返回 ApiResponse<T>；无业务响应体的下载返回 Future<void>
// 4. upload 方法单独处理文件上传，因为文件上传需要 FormData 和进度回调
//
// 为什么需要这个接口：
// - 测试时不需要启动真实服务器，传入 FakeApiService 即可
// - Repository 不接触 Dio 实例、Options、Interceptor 和 DioException
// - CancelToken/ProgressCallback 仍是刻意保留的 Dio 生命周期类型；若未来彻底
//   更换网络库，需要先在本接口抽象取消令牌与进度回调，再迁移 Repository 签名

import 'package:dio/dio.dart';

import 'api_response.dart';
import 'request_context.dart';

/// 网络服务抽象接口。
///
/// Repository 依赖这个接口，而不是直接操作 ApiClient 或 Dio 实例。
/// 这样做的好处：
/// 1. 单元测试时可以传入 FakeApiService，不需要真实网络请求
/// 2. HTTP 调用、响应适配和异常转换可以集中替换，不散落到 Repository
/// 3. Repository 只保留 CancelToken/ProgressCallback 的受控类型耦合
abstract class ApiService {
  /// 所有数据请求共同遵守的约定：
  ///
  /// - 泛型 `T` 是 Repository 期望拿到的业务数据类型，不是整个 HTTP body 类型；
  /// - [fromJson] 只解析响应中的业务 data。复杂 Model 必须提供；简单 String、Map、
  ///   List 且运行时类型完全一致时才可以省略；
  /// - 成功返回 `ApiResponse<T>`，业务数据位于 `response.data`；
  /// - HTTP、业务码和协议错误分别转换为 ApiException/BusinessException；
  /// - CancelToken 取消后 Future 以取消异常结束，上层状态工具通常会静默忽略。
  ///
  /// 下面每个方法中的 [context] 都表示当前单次请求的元数据，例如 requestId、
  /// 幂等键、是否允许网络重试和 401 后重放策略；它不是 BuildContext。

  /// GET 请求：通常用于获取列表、详情等读取类接口。
  ///
  /// - [path]：接口路径（不含 baseUrl），例如 `/home/banners`；
  /// - [queryParameters]：URL 查询参数 Map，例如 `{'page': 1, 'size': 20}`；Dio
  ///   负责 URL 编码，不要手工把用户输入拼进 path；
  /// - [cancelToken]：通常由 ViewModel 创建并在 `ref.onDispose` 中取消；
  /// - [context]：当前请求的追踪、重试和临时 Header 配置；
  /// - [fromJson]：把业务 data 转成 T，例如
  ///   `(json) => UserModel.fromJson(json as Map<String, dynamic>)`。
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  });

  /// POST 请求：通常用于登录、创建资源、提交表单等写入类接口。
  ///
  /// - [path]、[queryParameters]、[cancelToken]、[fromJson] 含义同 GET；
  /// - [data]：请求体，可以是 Map、List、FormData 或 Model.toJson() 结果；
  /// - [context]：写请求默认不重试。只有后端支持幂等键时，才同时设置稳定
  ///   idempotencyKey 与 allowRetry；支付等敏感操作还应把 replayPolicy 设为 never。
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  });

  /// PUT 请求：通常用于完整更新资源。
  ///
  /// 参数说明同 POST。
  /// HTTP 语义上 PUT 应设计为幂等；后端仍需正确实现，客户端不能仅凭方法名
  /// 假定重复提交一定安全。
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  });

  /// PATCH 请求：只更新资源的部分字段。
  ///
  /// 参数与 POST 相同。PATCH 默认不视为幂等；即使只改一个字段，也不能在未确认
  /// 服务端语义时开启自动重试。
  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  });

  /// DELETE 请求：通常用于删除资源。
  ///
  /// 保留 data 和 queryParameters 参数以兼容不同后端风格：
  /// - 有些后端把删除参数放在 URL 路径中：/users/123
  /// - 有些后端把删除参数放在请求体中：{"ids": [1, 2, 3]}
  /// - 有些后端把删除参数放在查询参数中：?id=123
  ///
  /// 删除通常具有不可逆业务影响。虽然 HTTP 语义可能幂等，仍应根据后端实现决定
  /// [context] 是否允许重试/重放，不能只凭方法名开启。
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  });

  /// 文件上传请求：用于上传头像、附件、图片等。
  ///
  /// [path]：上传接口路径
  /// [filePath]：本地文件路径
  /// [fileField]：后端接收文件的字段名，默认 'file'
  /// [data]：随文件一起发送的额外字段
  /// [onSendProgress]：上传进度回调，用于显示进度条
  /// [cancelToken]：取消令牌
  /// [context]：请求元数据；ApiClient 会强制禁止上传流自动重放
  /// [fromJson]：JSON 转 Model 回调（上传结果通常返回文件 URL 等）
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required String filePath,
    String fileField = 'file',
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
    RequestContext? context,
    T Function(dynamic json)? fromJson,
  });

  /// 下载文件到 [savePath]，支持进度回调和生命周期取消。
  ///
  /// - [path]：远端文件接口路径；
  /// - [savePath]：设备上最终写入的完整文件路径，目录存在性和存储权限由调用方保证；
  /// - [queryParameters]：下载地址的查询参数；
  /// - [onReceiveProgress]：回调参数依次是已接收字节数和总字节数；服务器未提供
  ///   Content-Length 时总数可能不可用，UI 不应盲目相除；
  /// - [cancelToken]：页面离开或用户点击停止时取消；
  /// - [context]：可携带 requestId/Header，但 ApiClient 强制禁止文件流自动重放。
  ///
  /// 成功完成时文件已经写入；本方法没有业务 data，所以返回 `Future<void>`。
  Future<void> download(
    String path,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    RequestContext? context,
  });
}
