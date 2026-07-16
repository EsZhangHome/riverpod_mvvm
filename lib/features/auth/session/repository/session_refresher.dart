// lib/features/auth/session/repository/session_refresher.dart
//
// 底座不知道客户后端使用 refresh_token、SSO Cookie 还是企业 OAuth，因此只
// 定义“尝试获得新 access token”这一最小能力。具体实现由项目注入，网络拦截器
// 不需要 import 某家登录 SDK，也不会和 AuthNotifier 形成循环依赖。

/// 认证模块向网络层提供的“刷新访问令牌”端口。
///
/// 使用接口而不是在拦截器里直接调用登录 Repository，可以避免 network 与 auth
/// 相互 import，也允许不同企业接入完全不同的会话协议。
abstract interface class SessionRefresher {
  /// 返回新 token 表示刷新成功；返回 null 表示会话不可恢复，需要退出登录。
  /// 实现时建议使用不带 UnauthorizedInterceptor 的独立客户端，避免刷新递归。
  ///
  /// 本方法没有参数，是因为 refresh token、Cookie 或 SDK 会话应封装在具体实现中，
  /// 不能由通用网络层读取。若调用失败可以抛异常，AuthNotifier 会把它当作刷新失败；
  /// 任何实现都不应返回旧 token 冒充刷新成功。
  Future<String?> refreshAccessToken();
}

/// 安全默认实现：底座不假设服务端一定支持刷新。
/// 未替换时 401 会得到 null，然后由 UnauthorizedGuard 统一清理登录态。
class DisabledSessionRefresher implements SessionRefresher {
  const DisabledSessionRefresher();

  @override
  Future<String?> refreshAccessToken() async => null;
}
