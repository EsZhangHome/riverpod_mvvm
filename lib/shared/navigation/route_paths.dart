// lib/shared/navigation/route_paths.dart
//
// 作用：集中管理所有路由路径常量，避免字符串散落在各页面和路由守卫中。
//
// 设计要点：
// 1. 所有路径使用 static const，编译时常量，零运行时开销
// 2. 私有构造函数防止实例化，这个类只作为常量容器
// 3. 路径片段统一使用小写；多单词路径的连接方式由项目路由规范统一约定
//
// 路由结构：
// /login            → 登录页
// /session-restoring → 安全会话恢复页
// /privacy-center    → 隐私中心（公开页面，登录前后都可查看）

/// 路由路径集中管理。
///
/// 底座内置路由结构：
/// /login            → 登录页
/// /session-restoring → 只在读取安全会话期间显示的内部页面
/// /privacy-center    → 隐私政策、用户协议、授权记录与撤回入口
class RoutePaths {
  const RoutePaths._();

  /// 登录页路径。
  static const String login = '/login';

  /// 安全会话恢复页。
  ///
  /// 这个地址不是原生启动图，也不是 BootstrapGate。BootstrapGate 完成环境校验和
  /// 普通存储初始化后，GoRouter 才使用本页面等待 SecureStorage 会话恢复。
  static const String sessionRestoring = '/session-restoring';

  /// 底座公共隐私中心。
  ///
  /// 该页面必须保持公开：用户在登录前也应能查看完整政策，退出登录后同样可以返回
  /// 查看。真实项目可以在设置页、关于页或登录页添加入口，但不要重复注册另一条
  /// 隐私状态来源；页面始终读取 App 级 privacyConsentProvider。
  static const String privacyCenter = '/privacy-center';
}
