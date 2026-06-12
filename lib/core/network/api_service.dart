// lib/core/network/api_service.dart
//
// 作用：定义网络服务的抽象接口，Repository 层依赖此接口而非具体实现。
//
// 架构职责：
// - 定义所有 HTTP 方法的签名（get/post/put/delete/upload）
// - 让 Repository 依赖抽象而非具体实现（依赖倒置原则）
// - 测试时可以用 FakeApiService 替换真实的 ApiClient
//
// 设计要点：
// 1. 每个方法都支持泛型 <T>，通过 fromJson 回调把原始 JSON 转成业务 Model
// 2. 每个方法都支持 CancelToken，由 ViewModel 透传以支持页面销毁时取消请求
// 3. 所有方法返回 ApiResponse<T>，统一了成功和失败的响应结构
// 4. upload 方法单独处理文件上传，因为文件上传需要 FormData 和进度回调
//
// 为什么需要这个接口：
// - 测试时不需要启动真实服务器，传入 FakeApiService 即可
// - 未来如果换网络库（如从 Dio 换成 http），只需要改 ApiClient 实现
// - Repository 不直接依赖 Dio，降低耦合度

import 'package:dio/dio.dart';

import 'api_response.dart';

/// 网络服务抽象接口。
///
/// Repository 依赖这个接口，而不是直接依赖 ApiClient 或 Dio。
/// 这样做的好处：
/// 1. 单元测试时可以传入 FakeApiService，不需要真实网络请求
/// 2. 未来换网络库时，只需要改 ApiClient 实现，Repository 不用动
/// 3. 符合依赖倒置原则：高层模块（Repository）不依赖低层模块（Dio）
abstract class ApiService {
  /// GET 请求：通常用于获取列表、详情等读取类接口。
  ///
  /// [path]：接口路径（不含 baseUrl），如 '/home/banners'
  /// [queryParameters]：URL 查询参数，如 ?page=1&size=10
  /// [cancelToken]：取消令牌，页面销毁时 ViewModel 会取消请求
  /// [fromJson]：将原始 JSON 转为业务 Model 的回调，如 (json) => UserModel.fromJson(json)
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    T Function(dynamic json)? fromJson,
  });

  /// POST 请求：通常用于登录、创建资源、提交表单等写入类接口。
  ///
  /// [path]：接口路径
  /// [data]：请求体，可以是 Map、List 或自定义对象的 toJson() 结果
  /// [queryParameters]：URL 查询参数
  /// [cancelToken]：取消令牌
  /// [fromJson]：JSON 转 Model 回调
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    T Function(dynamic json)? fromJson,
  });

  /// PUT 请求：通常用于完整更新资源。
  ///
  /// 参数说明同 POST。
  /// 与 POST 的区别：PUT 是幂等的（多次调用结果相同），POST 不是。
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    T Function(dynamic json)? fromJson,
  });

  /// DELETE 请求：通常用于删除资源。
  ///
  /// 保留 data 和 queryParameters 参数以兼容不同后端风格：
  /// - 有些后端把删除参数放在 URL 路径中：/users/123
  /// - 有些后端把删除参数放在请求体中：{"ids": [1, 2, 3]}
  /// - 有些后端把删除参数放在查询参数中：?id=123
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
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
  /// [fromJson]：JSON 转 Model 回调（上传结果通常返回文件 URL 等）
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required String filePath,
    String fileField = 'file',
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
    T Function(dynamic json)? fromJson,
  });
}
