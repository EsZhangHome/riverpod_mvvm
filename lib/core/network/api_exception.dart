// lib/core/network/api_exception.dart
//
// 作用：定义网络层统一异常体系，把 Dio 的复杂错误类型转换为 ViewModel 能理解的简单结构。
//
// 异常层次：
// ApiException（基类：网络层统一异常）
//   ├── 由 ApiException.fromDioException 创建（网络/超时/服务器等底层异常）
//   └── BusinessException（响应协议已成功解析，但业务 code 表示失败）
//
// 设计要点：
// 1. ViewModel 只需要捕获 ApiException，不需要 import Dio
// 2. BusinessException 携带后端确认可展示的 userMessage
// 3. 错误码使用负数常量，避免与 HTTP 状态码和后端业务码冲突
// 4. fromDioException 把 DioExceptionType 转成稳定 FailureKind；展示文案由 shared 解析

import 'package:dio/dio.dart';

import '../errors/app_failure.dart';

/// 网络层统一异常。
///
/// ViewModel 只关心 code 和 message，不需要知道 Dio 的复杂错误类型。
/// 所有网络相关异常最终都会转换为 ApiException 或其子类。
class ApiException extends AppFailure {
  const ApiException({
    required this.code,
    required this.message,
    super.kind = FailureKind.protocol,
  }) : super(debugMessage: message, failureCode: code);

  /// 错误码。
  /// 正数：HTTP 状态码或后端业务码
  /// 负数：客户端自定义错误码（见下方常量）
  final int code;

  /// 技术错误描述，用于日志与诊断，不应绕过 FailureMessageResolver 直接展示。
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
  /// 把 Dio 的 DioExceptionType 枚举逐一映射为稳定失败分类：
  /// - connectionTimeout / sendTimeout / receiveTimeout → 超时
  /// - badResponse → HTTP 错误；401/403 会进一步映射为认证/权限分类
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
          message: 'Request timed out',
          kind: FailureKind.timeout,
        );

      // ---- 服务器返回错误 ----
      // HTTP 状态码 >= 400，包括 4xx 和 5xx
      case DioExceptionType.badResponse:
        return ApiException(
          code: error.response?.statusCode ?? serverError,
          // 优先使用后端返回的错误 message，没有则用默认文案
          message: _messageFromResponse(error.response),
          kind: (error.response?.statusCode ?? 0) == 401
              ? FailureKind.authentication
              : (error.response?.statusCode ?? 0) == 403
              ? FailureKind.permission
              : FailureKind.server,
        );

      // ---- 请求被取消 ----
      // 通常是页面销毁时 cancelToken.cancel() 导致
      case DioExceptionType.cancel:
        return const ApiException(
          code: cancelledError,
          message: 'Request cancelled',
          kind: FailureKind.cancellation,
        );

      // ---- 网络连接异常 ----
      // 无网络、DNS 解析失败、连接被拒绝等
      case DioExceptionType.connectionError:
        return const ApiException(
          code: networkError,
          message: 'Network connection failed',
          kind: FailureKind.network,
        );

      // ---- 证书校验失败 ----
      // HTTPS 证书无效或过期
      case DioExceptionType.badCertificate:
        return const ApiException(
          code: networkError,
          message: 'Certificate validation failed',
          kind: FailureKind.network,
        );

      // ---- 未知错误 ----
      // 无法归类的异常，兜底处理
      case DioExceptionType.unknown:
        return const ApiException(
          code: unknownError,
          message: 'Unknown network error',
          kind: FailureKind.unknown,
        );

      // Dio 后续版本可能新增异常类型。底座不能因为依赖包增加枚举值就无法编译，
      // 未识别类型统一映射为 unknown；网络日志只记录脱敏后的错误类型与状态码。
      // ignore: unreachable_switch_default
      default:
        return const ApiException(
          code: unknownError,
          message: 'Unknown network error',
          kind: FailureKind.unknown,
        );
    }
  }

  /// 从 Dio Response 中提取错误提示文案。
  ///
  /// 尝试提取后端 message 作为诊断信息；HTTP 错误仍由展示层按 FailureKind
  /// 使用本地化通用文案；BusinessException 也只有明确标记安全时才展示原文。
  static String _messageFromResponse(Response<dynamic>? response) {
    final data = response?.data;
    // 检查后端返回的 JSON 中是否包含 message 字段
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    // 后端没有提供 message，使用默认文案
    return 'Server returned an error response';
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
/// - userMessage：业务错误原文，是否可展示还要看 canDisplayMessage
///
/// AsyncRequestHandler 只在 canDisplayMessage=true 时使用原文，否则返回通用文案。
class BusinessException extends ApiException {
  BusinessException({
    required super.code,
    required this.userMessage,
    this.canDisplayMessage = true,
  }) : super(message: userMessage, kind: FailureKind.business);

  /// 业务错误原文。手工创建的领域错误可传已审核文案；网络适配器默认把
  /// canDisplayMessage 设为 false，防止网关或服务端内部信息直接进入 UI。
  final String userMessage;

  /// 只有协议适配器明确确认脱敏后，网络响应文案才允许直接展示。
  final bool canDisplayMessage;
}
