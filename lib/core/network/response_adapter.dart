// lib/core/network/response_adapter.dart
//
// 不同公司的响应格式不同：有的返回 {code,message,data}，有的直接返回 REST
// 对象。协议判断集中在 Adapter，Repository 只负责 JSON -> Model，ApiClient
// 只负责网络与异常。只要业务 data 结构不变，切换外层响应协议时替换 Provider，
// 不需要逐个修改 Repository。

import 'package:dio/dio.dart';

import '../config/env_config.dart';
import 'api_response.dart';

/// 把某个公司的 HTTP 响应协议转换成底座统一的 [ApiResponse]。
///
/// 这是网络基础设施与业务 Repository 之间的“翻译器”。Repository 提供 decoder
/// 把业务 data 转成 Model；Adapter 只解释成功码、消息和 data 在响应中的位置。
abstract interface class ResponseAdapter {
  /// 把一次 Dio Response 转换为统一 `ApiResponse<T>`。
  ///
  /// - [response]：包含 HTTP 状态、Header 和原始 body 的 Dio 响应；
  /// - [decoder]：由 Repository 提供，只解析真正的业务 data，不解析外层协议；
  /// - 返回值：携带统一 code/message/data 和明确成功判定的 ApiResponse。
  ///
  /// 协议字段类型不合法或 decoder 抛错时应继续抛出，由 ApiClient 转成 protocol
  /// failure；Adapter 不应静默制造空 Model 掩盖后端契约变化。
  ApiResponse<T> adapt<T>(
    Response<dynamic> response,
    T Function(dynamic json)? decoder,
  );
}

/// 兼容 `{code, message, data}`，同时允许普通对象/数组直接作为响应体。
class EnvelopeResponseAdapter implements ResponseAdapter {
  /// 创建可配置的业务外壳适配器。
  ///
  /// - [codeKey]：业务码字段名，默认 `code`；
  /// - [messageKey]：业务提示字段名，默认 `message`；
  /// - [dataKey]：真正业务数据字段名，默认 `data`；
  /// - [successCode]：业务码模式下代表成功的整数；
  /// - [useHttpStatus]：true 时只按 HTTP 2xx 判断成功，false 时按 [successCode]；
  /// - [trustBusinessMessage]：是否允许失败 message 最终进入 UI，默认 false。只有
  ///   后端明确保证脱敏、可本地化且不含内部细节时才能开启。
  ///
  /// 如果响应 Map 根本没有 [codeKey]，本适配器把整个 body 当普通 REST 数据，而
  /// 不是强行读取 dataKey。
  const EnvelopeResponseAdapter({
    this.codeKey = 'code',
    this.messageKey = 'message',
    this.dataKey = 'data',
    this.successCode = EnvConfig.apiSuccessCode,
    this.useHttpStatus = EnvConfig.useHttpStatus,
    this.trustBusinessMessage = false,
  });

  /// 业务码字段名。
  final String codeKey;

  /// 业务提示字段名。
  final String messageKey;

  /// 业务数据字段名。
  final String dataKey;

  /// 业务码模式下代表成功的 code。
  final int successCode;

  /// true 使用 HTTP 2xx；false 使用业务 [successCode]。
  final bool useHttpStatus;

  /// 是否把外壳 message 标记为经过服务端安全保证、允许展示。
  final bool trustBusinessMessage;

  @override
  ApiResponse<T> adapt<T>(
    Response<dynamic> response,
    T Function(dynamic json)? decoder,
  ) {
    final body = response.data;
    final statusCode = response.statusCode ?? 0;
    final httpSuccess = statusCode >= 200 && statusCode < 300;

    // 只有存在 codeKey 才视为业务外壳。普通用户对象也可能是 Map，不能仅凭
    // “它是 Map”就读取 data，否则会错误丢掉整个响应。
    if (body is Map<String, dynamic> && body.containsKey(codeKey)) {
      final rawCode = body[codeKey];
      final code = rawCode is num ? rawCode.toInt() : statusCode;
      final rawData = body[dataKey];
      return ApiResponse<T>(
        code: code,
        message: body[messageKey]?.toString() ?? '',
        data: _decode(rawData, decoder),
        successOverride: useHttpStatus ? httpSuccess : code == successCode,
        canDisplayMessage: trustBusinessMessage,
      );
    }

    // 普通 REST 对象和数组直接交给业务 decoder，不再误判为响应外壳。
    return ApiResponse<T>(
      code: statusCode,
      message: response.statusMessage ?? '',
      data: _decode(body, decoder),
      successOverride: httpSuccess,
      canDisplayMessage: false,
    );
  }

  T? _decode<T>(dynamic value, T Function(dynamic json)? decoder) {
    // 无 decoder 时仅适合 T 与 JSON 运行时类型一致的简单值/Map/List；
    // 业务 Model 应始终传 fromJson，让类型错误尽早暴露为协议异常。
    if (value == null) return null;
    return decoder == null ? value as T : decoder(value);
  }
}

/// 完全依赖 HTTP 状态码、响应体就是业务数据的 REST 适配器。
///
/// 适合 `GET /users/1` 直接返回 `{id, name}` 的后端，不读取 code/message/data。
/// 2xx 判定成功，整个 body 交给 decoder；HTTP statusMessage 只保留为诊断信息，
/// 默认不会直接展示给用户。
class DirectResponseAdapter implements ResponseAdapter {
  const DirectResponseAdapter();

  @override
  ApiResponse<T> adapt<T>(
    Response<dynamic> response,
    T Function(dynamic json)? decoder,
  ) {
    // Direct 模式没有业务 code 外壳：2xx 就是成功，整个 body 都是业务数据。
    final statusCode = response.statusCode ?? 0;
    final body = response.data;
    return ApiResponse<T>(
      code: statusCode,
      message: response.statusMessage ?? '',
      data: body == null
          ? null
          : decoder == null
          ? body as T
          : decoder(body),
      successOverride: statusCode >= 200 && statusCode < 300,
      canDisplayMessage: false,
    );
  }
}
