// Login 子模块拥有自己的接口路径，core 网络层不应知道“登录”这种业务语义。

abstract final class AuthEndpoints {
  /// 登录接口的相对路径，会与 EnvConfig.apiBaseUrl 组合。
  ///
  /// 集中声明路径可以避免 Repository 到处出现魔法字符串；接入真实后端时只在本
  /// 模块修改。不要在这里写完整域名，域名属于环境配置，不属于认证业务。
  static const login = '/auth/login';
}
