// lib/core/network/api_exception.dart
//
// 作用：定义网络层统一异常体系，把 Dio 的复杂错误类型转换为 ViewModel 能理解的简单结构。
//
// 异常层次：
// ApiException（基类：网络层统一异常）
//   ├── 由 ApiException.fromDioException 创建（网络/超时/服务器等底层异常）
//   └── BusinessException（业务异常：后端返回的业务错误，如余额不足、权限不够）
//
// 设计要点：
// 1. ViewModel 只需要捕获 ApiException，不需要 import Dio
// 2. BusinessException 携带 userMessage，可以直接展示给用户
// 3. 错误码使用负数常量，避免与 HTTP 状态码和后端业务码冲突
// 4. fromDioException 把 DioExceptionType 枚举转为用户可读的文案

import 'package:dio/dio.dart';

import '../l10n/app_strings.dart';

/// 网络层统一异常。
///
/// ViewModel 只关心 code 和 message，不需要知道 Dio 的复杂错误类型。
/// 所有网络相关异常最终都会转换为 ApiException 或其子类。
class ApiException implements Exception {
  const ApiException({required this.code, required this.message});

  /// 错误码。
  /// 正数：HTTP 状态码或后端业务码
  /// 负数：客户端自定义错误码（见下方常量）
  final int code;

  /// 错误提示文案，可以直接展示给用户。
  final String message;

  // ==================== 客户端自定义错误码（负数，避免与正数 HTTP 码冲突） ====================

  /// 网络连接异常：无网络、DNS 解析失败、连接被拒绝等。
  static const int networkError = -1;

  /// 请求超时：连接超时、发送超时、接收超时。
  static const int timeoutError = -2;

  /// 服务器异常：HTTP 5xx 错误。
  static const int serverError = -3;

  /// 未知错误：无法归类的异常。
  static const int unknownError = -4;

  /// 请求被调用方主动取消，不属于用户可见的请求失败。
  static const int cancelledError = -5;

  bool get isCancelled => code == cancelledError;

  /// 工厂方法：从 DioException 创建 ApiException。
  ///
  /// 把 Dio 的 DioExceptionType 枚举逐一映射为用户可读的文案：
  /// - connectionTimeout / sendTimeout / receiveTimeout → 超时
  /// - badResponse → 服务器返回错误（5xx）或业务错误（4xx）
  /// - cancel → 请求被取消
  /// - connectionError → 网络连接异常
  /// - badCertificate → 证书校验失败
  /// - unknown → 未知错误
  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      // ---- 超时类错误 ----
      // 连接超时、发送超时、接收超时都归为超时错误
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          code: timeoutError,
          message: AppStrings.requestTimeout,
        );

      // ---- 服务器返回错误 ----
      // HTTP 状态码 >= 400，包括 4xx 和 5xx
      case DioExceptionType.badResponse:
        return ApiException(
          code: error.response?.statusCode ?? serverError,
          // 优先使用后端返回的错误 message，没有则用默认文案
          message: _messageFromResponse(error.response),
        );

      // ---- 请求被取消 ----
      // 通常是页面销毁时 cancelToken.cancel() 导致
      case DioExceptionType.cancel:
        return const ApiException(
          code: cancelledError,
          message: AppStrings.requestCanceled,
        );

      // ---- 网络连接异常 ----
      // 无网络、DNS 解析失败、连接被拒绝等
      case DioExceptionType.connectionError:
        return const ApiException(
          code: networkError,
          message: AppStrings.networkError,
        );

      // ---- 证书校验失败 ----
      // HTTPS 证书无效或过期
      case DioExceptionType.badCertificate:
        return const ApiException(
          code: networkError,
          message: AppStrings.certificateError,
        );

      // ---- 未知错误 ----
      // 无法归类的异常，兜底处理
      case DioExceptionType.unknown:
        return const ApiException(
          code: unknownError,
          message: AppStrings.unknownError,
        );
    }
  }

  /// 从 Dio Response 中提取错误提示文案。
  ///
  /// 优先使用后端返回的 message 字段，这样业务错误信息能直接展示给用户。
  /// 如果后端没有返回 message，使用默认的"服务器异常"提示。
  static String _messageFromResponse(Response<dynamic>? response) {
    final data = response?.data;
    // 检查后端返回的 JSON 中是否包含 message 字段
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    // 后端没有提供 message，使用默认文案
    return AppStrings.serverError;
  }

  @override
  String toString() => message;
}

/// 业务异常：后端返回的业务错误。
///
/// 与 ApiException 的区别：
/// - ApiException：底层网络异常（超时、无网络、服务器 500 等）
/// - BusinessException：后端业务逻辑错误（账号冻结、余额不足、权限不够等）
///
/// 这类异常有两个 message：
/// - message（继承自 ApiException）：与 userMessage 相同
/// - userMessage：后端返回的、可直接展示给用户的文案
///
/// 在 BaseViewModel.asyncRequest 中，BusinessException 会被特殊处理，
/// 直接使用 userMessage 展示给用户。
class BusinessException extends ApiException {
  BusinessException({required super.code, required this.userMessage})
    : super(message: userMessage);

  /// 后端返回的用户可见错误文案。
  /// 例如："账号已被冻结，请联系客服"、"余额不足"、"权限不足"等。
  final String userMessage;
}
