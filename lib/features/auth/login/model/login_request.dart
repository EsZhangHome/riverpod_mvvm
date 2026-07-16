// lib/features/auth/login/model/login_request.dart
//
// 作用：登录请求参数模型，封装登录接口需要的请求体字段。
//
// 设计要点：
// 1. 使用 json_serializable 生成 toJson，减少手写字段映射错误
// 2. 使用 const 构造函数，所有字段都是 final
// 3. ViewModel 组装 LoginRequest，Repository 把它传给 ApiService
//
// 数据流：
// LoginPage → LoginViewModel.login(account, password)
//   → 组装 LoginRequest(account, password)
//   → LoginRepository.login(request)
//   → ApiService.post(data: request.toJson())

import 'package:json_annotation/json_annotation.dart';

part 'login_request.g.dart';

/// 登录请求参数模型。
///
/// 封装登录接口需要的账号和密码。
/// 后续可以扩展字段（如验证码、设备信息等）。
@JsonSerializable()
class LoginRequest {
  /// 创建登录请求。
  ///
  /// [account] 与 [password] 都是用户输入清洗后的值：当前 LoginNotifier 会 trim
  /// account，但不会 trim password，因为空格可能就是密码的一部分。本构造函数只
  /// 表达请求数据，不重复做表单校验。
  const LoginRequest({required this.account, required this.password});

  /// 登录账号。示例支持手机号或邮箱，真实项目可按后端协议改名/扩展。
  final String account;

  /// 原始密码。只用于本次请求，不应写入 Provider 状态、持久化缓存或日志。
  final String password;

  /// 从 JSON Map 创建 LoginRequest。
  ///
  /// 一般登录请求不会从接口解析回来，但保留 fromJson 可以让生成代码完整，
  /// 也方便后续做表单草稿、本地缓存或测试数据构造。
  factory LoginRequest.fromJson(Map<String, dynamic> json) {
    return _$LoginRequestFromJson(json);
  }

  /// 序列化为 JSON Map，用于 POST 请求体。
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}
