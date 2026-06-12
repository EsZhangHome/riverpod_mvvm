// lib/features/login/model/login_request.dart
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
  const LoginRequest({required this.account, required this.password});

  /// 账号：手机号或邮箱
  final String account;

  /// 密码
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
