/// 登录表单缺少的第一个必填项。
///
/// ViewModel 用它决定展示哪条 Toast；View 在“刚从协议弹窗同意”这一特殊路径只判断
/// 是否完整，不展示消息。两处共享同一规则，避免以后账号规则修改后行为不一致。
enum LoginInputIssue { accountRequired, passwordRequired }

/// 登录输入的纯校验规则，不读取 Widget、Riverpod 或网络状态。
abstract final class LoginInputRules {
  /// 按页面从上到下返回第一个缺失字段；null 表示可以发起登录用例。
  static LoginInputIssue? firstIssue(String account, String password) {
    if (account.trim().isEmpty) return LoginInputIssue.accountRequired;
    if (password.isEmpty) return LoginInputIssue.passwordRequired;
    return null;
  }

  static bool isComplete(String account, String password) =>
      firstIssue(account, password) == null;
}
