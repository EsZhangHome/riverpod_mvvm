// lib/core/network/api_response.dart
//
// 作用：定义 ResponseAdapter 交给 Repository 的统一响应结果。
//
// 设计要点：
// 1. 泛型 T 表示 data 的实际类型，如 ApiResponse<UserModel>、ApiResponse<List<HomeBanner>>
// 2. successOverride 保存当前 ResponseAdapter 已解释好的成功结果
// 3. canDisplayMessage 明确控制服务端 message 是否允许进入 UI
// 4. fromJson 只是 `{code,message,data}` 的便捷工厂；真实请求由 ResponseAdapter 解析
//
// 使用示例：
// ```dart
// // 单独解析标准业务外壳时：
// final apiResponse = ApiResponse<UserModel>.fromJson(
//   json,
//   (json) => UserModel.fromJson(json as Map<String, dynamic>),
// );
// // apiResponse.data 已经是 UserModel 类型
// ```

import '../config/env_config.dart';

/// 网络层统一响应结构。
///
/// 假设后端返回的 JSON 格式为：
/// ```json
/// {
///   "code": 0,
///   "message": "success",
///   "data": { ... }
/// }
/// ```
///
/// 如果实际后端字段名不同（如 code 叫 status、data 叫 result），应替换
/// ResponseAdapter，而不是让每个 Repository 自己解释协议。
class ApiResponse<T> {
  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.successOverride,
    this.canDisplayMessage = false,
  });

  /// 业务状态码或 HTTP 状态码，具体含义由 ResponseAdapter 决定。
  final int code;

  /// 业务提示消息。
  /// 成功时通常为 "success"，失败时包含错误原因。
  final String message;

  /// 响应数据，类型由泛型 T 决定。
  /// 成功时包含业务数据，失败时可能为 null。
  final T? data;
  final bool? successOverride;

  /// true 表示后端协议明确保证 message 已脱敏，可直接展示给用户。
  final bool canDisplayMessage;

  /// 判断本次请求是否成功。
  ///
  /// ResponseAdapter 提供 successOverride 时直接使用适配结果；没有 override 的
  /// 手工构造对象才通过 EnvConfig.useHttpStatus 使用以下兜底规则：
  ///
  /// 模式 1（useHttpStatus = true）：使用 HTTP 状态码判断
  /// - 200-299 表示成功
  /// - 适合 RESTful 风格的后端
  ///
  /// 模式 2（useHttpStatus = false，默认）：使用业务码判断
  /// - code == EnvConfig.apiSuccessCode（默认 0）表示成功
  /// - 适合国内常见业务码风格的后端
  bool get isSuccess {
    if (successOverride != null) return successOverride!;
    if (EnvConfig.useHttpStatus) {
      // HTTP 状态码模式：200-299 都是成功
      return code >= 200 && code < 300;
    }
    // 业务码模式：只有特定 code 才表示成功
    return code == EnvConfig.apiSuccessCode;
  }

  /// 从 JSON Map 创建 ApiResponse 实例。
  ///
  /// [json]：后端返回的原始 JSON Map
  /// [fromJsonT]：将 data 字段转为具体业务类型的回调
  ///   - 为 null 时：直接把 data 当作 T 类型返回（适合简单类型如 String、int）
  ///   - 不为 null 时：调用 fromJsonT(json['data']) 转换（适合复杂类型如 UserModel）
  ///
  /// 示例：
  /// ```dart
  /// // 简单类型，不需要 fromJsonT
  /// ApiResponse<String>.fromJson({'code': 0, 'message': 'ok', 'data': 'hello'}, null);
  ///
  /// // 复杂类型，需要 fromJsonT
  /// ApiResponse<UserModel>.fromJson(
  ///   {'code': 0, 'message': 'ok', 'data': {'id': '1', 'name': 'Tom'}},
  ///   (json) => UserModel.fromJson(json as Map<String, dynamic>),
  /// );
  /// ```
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      // code 字段缺失时默认 0
      code: json['code'] as int? ?? 0,
      // message 字段缺失时默认空字符串
      message: json['message'] as String? ?? '',
      // 根据 fromJsonT 是否为空决定 data 的转换方式
      // fromJsonT 为空 → 直接把 json['data'] 当作 T 类型
      // fromJsonT 不为空 → 调用 fromJsonT 把 json['data'] 转成 T
      data: fromJsonT == null ? json['data'] as T? : fromJsonT(json['data']),
    );
  }
}
