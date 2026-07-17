/// 登录表单必填项的校验结果。
///
/// ViewModel 用它决定展示哪条 Toast；View 在“刚从协议弹窗同意”这一特殊路径只判断
/// 是否完整，不展示消息。两处共享同一规则，避免以后账号规则修改后行为不一致。
enum LoginInputIssue {
  /// 账号和密码都没有填写，需要一次完整说明，避免用户连续提交两次才知道全部要求。
  accountAndPasswordRequired,

  /// 只缺少登录账号。
  accountRequired,

  /// 只缺少密码。
  passwordRequired,
}

/// 登录输入的纯校验规则，不读取 Widget、Riverpod 或网络状态。
abstract final class LoginInputRules {
  /// 返回当前缺失字段的精确组合；null 表示可以发起登录用例。
  static LoginInputIssue? firstIssue(String account, String password) {
    final isAccountEmpty = account.trim().isEmpty;
    final isPasswordEmpty = password.isEmpty;

    if (isAccountEmpty && isPasswordEmpty) {
      return LoginInputIssue.accountAndPasswordRequired;
    }
    if (isAccountEmpty) return LoginInputIssue.accountRequired;
    if (isPasswordEmpty) return LoginInputIssue.passwordRequired;
    return null;
  }

  static bool isComplete(String account, String password) =>
      firstIssue(account, password) == null;
}
