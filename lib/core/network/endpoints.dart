// lib/core/network/endpoints.dart
//
// 作用：集中管理所有接口地址常量，避免路径字符串散落在代码各处。
//
// 设计要点：
// 1. 所有接口路径集中定义，换后端环境时不需要到处搜索字符串
// 2. baseUrl 从 EnvConfig 读取，通过 --dart-define 切换开发/测试/生产环境
// 3. 使用 const 构造函数并私有化，防止被实例化
// 4. 所有路径常量都是 static const，编译时常量，零运行时开销
//
// 使用方式：
// ```dart
// ApiClient.instance.get(Endpoints.homeBanners, fromJson: ...);
// ```

import '../config/env_config.dart';

/// 所有接口地址集中管理。
///
/// 新增接口时，只需要在这里添加一个 static const 字段即可。
/// 不要在页面或 Repository 中直接写路径字符串。
class Endpoints {
  /// 私有构造函数，防止实例化。这个类只作为常量容器使用。
  const Endpoints._();

  /// 接口基础地址，从环境配置中读取。
  /// 通过 --dart-define=ENV_API_BASE_URL=https://xxx 切换环境。
  static const String baseUrl = EnvConfig.apiBaseUrl;

  /// 登录接口：POST /auth/login
  /// 请求体：{ "account": "xxx", "password": "xxx" }
  /// 响应：{ "code": 0, "data": { "token": "xxx", "user": {...} } }
  static const String login = '/auth/login';

  /// 首页 Banner 列表：GET /home/banners
  /// 响应：{ "code": 0, "data": [{ "id": "1", "title": "xxx", "imageUrl": "xxx" }] }
  static const String homeBanners = '/home/banners';

  /// 用户个人资料：GET /user/profile
  /// 响应：{ "code": 0, "data": { "id": "1", "name": "xxx", "email": "xxx" } }
  static const String profile = '/user/profile';
}
