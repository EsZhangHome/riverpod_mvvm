// lib/shared/localization/app_strings.dart
//
// 底座仍需要少量不依赖 BuildContext 的通用中文文案，例如异步处理器把
// AppFailure 转成安全提示时无法直接读取 AppLocalizations。
//
// 这里只保存跨项目仍然成立的认证、错误和空状态文案；具体业务文案必须由
// 所属 feature 管理或写入 ARB，避免 shared 逐渐变成无法维护的文案仓库。
// 新增页面时优先使用 lib/l10n/*.arb，而不是继续扩充这个静态类。

/// 仅供底层状态工具、认证和通用错误页使用的最小文案集合。
class AppStrings {
  const AppStrings._();

  // ==================== 认证与通用操作 ====================

  static const String login = '登录';
  static const String account = '手机号/邮箱';
  static const String password = '密码';
  static const String enterAccountAndPassword = '请输入账号和密码';
  static const String retry = '重试';
  static const String backHome = '返回首页';
  static const String noData = '暂无数据';
  static const String pageNotFound = '页面不存在';

  // ==================== 用户安全错误提示 ====================

  /// 下列文案面向用户，不包含 URL、堆栈、服务端原始响应等敏感诊断信息。
  /// 技术细节可保存在 AppFailure.debugMessage，并由请求边界或业务代码按需上报。
  static const String requestTimeout = '请求超时，请稍后重试';
  static const String requestCanceled = '请求已取消';
  static const String networkError = '网络连接异常';
  static const String unknownError = '未知错误，请稍后重试';
  static const String serverError = '服务器异常，请稍后重试';
  static const String requestFailed = '请求失败，请稍后重试';
  static const String sessionExpired = '登录状态已失效，请重新登录';
  static const String permissionDenied = '暂无权限执行此操作';
  static const String validationFailed = '提交内容校验失败';
  static const String storageError = '本地数据处理失败';
  static const String protocolError = '服务响应格式异常';
}
