import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 登录页“已阅读并同意协议”勾选状态。
///
/// 这是页面交互状态，不等于持久化隐私同意记录：
/// - 勾选只说明用户当前准备提交；真正保存由 App 注入的 beforeLogin 完成；
/// - 隐私政策升级时，App 组合层可以调用 unselect，使旧勾选立即失效；
/// - autoDispose 保证离开登录页后不会把临时 UI 选择长期留在内存。
final class LoginAgreementSelectionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setSelected(bool selected) {
    if (state == selected) return;
    state = selected;
  }

  void unselect() => setSelected(false);
}

final loginAgreementSelectionProvider =
    NotifierProvider.autoDispose<LoginAgreementSelectionNotifier, bool>(
      LoginAgreementSelectionNotifier.new,
    );
