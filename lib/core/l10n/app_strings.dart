// lib/core/l10n/app_strings.dart
//
// 作用：集中管理 App 中所有用户可见的文案字符串。
//
// 设计要点：
// 1. 所有文案使用 static const 常量，编译时常量，零运行时开销
// 2. 当前只支持中文，后续可扩展为 arb 文件实现国际化
// 3. 集中管理的好处：文案变更时只需改这一个文件，不需要搜索整个项目
// 4. 分类清晰：导航类、操作类、错误提示类、Mock 提示类
//
// 国际化扩展方式：
// 1. 安装 flutter_localizations 依赖（已安装）
// 2. 创建 lib/l10n/app_zh.arb 和 lib/l10n/app_en.arb
// 3. 在 l10n.yaml 中配置
// 4. 使用 AppLocalizations.of(context).xxx 替换 AppStrings.xxx
// 5. 页面代码改动最小，因为 AppStrings 是集中管理的

/// App 文案集中管理。
///
/// 当前先用静态常量，后续接 arb 文件时页面代码改动最小。
/// 不要在页面中直接写中文字符串。
class AppStrings {
  const AppStrings._();

  // ==================== 导航类 ====================

  /// App 名称
  static const String appName = 'MVVM Demo';

  /// 首页 Tab 标题
  static const String home = '首页';

  /// 社区 Tab 标题
  static const String community = '社区';

  /// 我的 Tab 标题
  static const String mine = '我的';

  /// 个人中心页面标题
  static const String profile = '个人中心';

  // ==================== 操作类 ====================

  /// 登录按钮文案
  static const String login = '登录';

  /// 退出登录按钮文案
  static const String logout = '退出登录';

  /// 重试按钮文案
  static const String retry = '重试';

  /// 返回首页按钮文案
  static const String backHome = '返回首页';

  /// 切换主题按钮提示
  static const String switchTheme = '切换主题';

  // ==================== 表单类 ====================

  /// 账号输入框标签
  static const String account = '手机号/邮箱';

  /// 密码输入框标签
  static const String password = '密码';

  /// 表单校验提示：账号或密码为空
  static const String enterAccountAndPassword = '请输入账号和密码';

  // ==================== 状态提示类 ====================

  /// 无数据时提示
  static const String noData = '暂无数据';

  /// 页面不存在（404）提示
  static const String pageNotFound = '页面不存在';

  // ==================== 错误提示类 ====================

  /// 请求超时提示
  static const String requestTimeout = '请求超时，请稍后重试';

  /// 请求已取消提示
  static const String requestCanceled = '请求已取消';

  /// 网络连接异常提示
  static const String networkError = '网络连接异常';

  /// 证书校验失败提示
  static const String certificateError = '证书校验失败';

  /// 未知错误提示
  static const String unknownError = '未知错误，请稍后重试';

  /// 服务器异常提示
  static const String serverError = '服务器异常，请稍后重试';

  /// 通用请求失败提示
  static const String requestFailed = '请求失败，请稍后重试';

  /// 用户信息缺失提示
  static const String userMissing = '用户信息不存在，请重新登录';

  // ==================== Mock 数据提示 ====================

  /// 首页 Banner 模拟数据提示
  static const String mockBannerTips = '模拟接口数据，可替换为真实 Banner 图片和跳转';

  /// 社区内容模拟数据提示
  static const String communityMockTips = '模拟社区内容，后续可接真实社区接口';
}
