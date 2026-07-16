// 登录用例与全局认证状态之间的最小端口。
//
// SignInUseCase 只需要表达“请建立这份完整会话”，不需要知道调用方最终使用
// AuthNotifier、Bloc 还是其他状态容器。把这个能力抽成接口后，应用用例不会反向
// 依赖某个 ViewModel 的具体类，也便于单元测试替换成内存 Fake。

import '../model/auth_session.dart';

/// 建立一份已经通过身份校验的全局认证会话。
abstract interface class SessionActivator {
  /// 安全保存 [session]，并在保存成功后发布全局已认证状态。
  ///
  /// 返回 true 表示持久化与内存状态都已完成；false 表示会话没有可靠建立，调用方
  /// 必须留在登录流程，不能把“接口返回成功”误当成“用户已经登录”。
  Future<bool> activateSession(AuthSession session);
}
