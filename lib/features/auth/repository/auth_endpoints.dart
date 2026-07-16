// Auth 模块拥有自己的接口路径，core 网络层不应知道“登录”这种业务语义。

abstract final class AuthEndpoints {
  static const login = '/auth/login';
}
