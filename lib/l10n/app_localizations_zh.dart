// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get initializationFailed => '应用初始化失败';

  @override
  String failedStages(String stages) {
    return '失败阶段：$stages';
  }

  @override
  String get retry => '重试';

  @override
  String get privacyConsentTitle => '协议与隐私保护说明';

  @override
  String get privacyInitialConsentIntroduction =>
      '首次使用前，请阅读隐私协议和用户协议。同意后会选中登录页协议选项；不同意只关闭本次弹窗并停留在登录页，不会发送登录请求。下次启动仍会再次提示。';

  @override
  String get privacyLoginConsentIntroduction =>
      '登录前需要你阅读并同意隐私协议和用户协议。同意后会选中登录页协议选项；账号密码已填写时继续登录，未填写时只选中协议，不显示输入提示。不同意则取消选中并停留在登录页。';

  @override
  String get privacyPolicyUpgradeTitle => '隐私政策已更新';

  @override
  String get privacyPolicyUpgradeIntroduction =>
      '隐私政策内容或版本已更新，请阅读后选择。同意后继续停留在当前页面；不同意将退出当前账号并返回登录页面。下次启动时仍会再次提示。';

  @override
  String get privacyPolicyUpgradeLoginIntroduction =>
      '隐私政策已经更新。重新登录前请阅读并确认；同意后继续本次登录，不同意则关闭弹窗并停留在登录页。';

  @override
  String privacyConsentVersion(String version) {
    return '授权版本：$version';
  }

  @override
  String privacyDocumentVersion(String version) {
    return '政策文档版本：$version';
  }

  @override
  String userAgreementDocumentVersion(String version) {
    return '用户协议文档版本：$version';
  }

  @override
  String get privacyPolicyAddress => '完整隐私政策地址';

  @override
  String get viewFullPrivacyPolicy => '阅读完整隐私政策';

  @override
  String get viewFullUserAgreement => '阅读完整用户协议';

  @override
  String get privacyPolicyOpenFailed => '暂时无法打开协议页面，请检查系统浏览器或网络后重试。';

  @override
  String get privacyDisclosureDataTitle => '处理哪些信息';

  @override
  String get privacyDisclosureDataBody =>
      '登录时处理你主动填写的账号和密码；具体业务需要其他信息时，必须在使用对应功能前另行说明。';

  @override
  String get privacyDisclosurePurposeTitle => '为什么处理';

  @override
  String get privacyDisclosurePurposeBody =>
      '用于身份验证、维护登录状态和保障账号安全，不应超出实现当前功能所必需的范围。';

  @override
  String get privacyDisclosureThirdPartyTitle => '权限与第三方';

  @override
  String get privacyDisclosureThirdPartyBody =>
      '同意前不会启动需要授权的延迟能力；正式项目必须在完整政策中逐项列明实际权限、SDK、共享数据和用途。';

  @override
  String get privacyDisclosureRightsTitle => '你的选择和权利';

  @override
  String get privacyDisclosureRightsBody =>
      '你可以拒绝并停留在登录页。正式项目还必须提供撤回同意、更正、删除、注销账号和投诉渠道。';

  @override
  String get agreeAndContinue => '同意并继续';

  @override
  String get agreeAndContinueUsing => '同意并继续使用';

  @override
  String get declineAndLogout => '不同意并退出登录';

  @override
  String get disagree => '不同意';

  @override
  String get privacyConsentSaveFailed => '同意状态保存失败，登录请求尚未发出，请重试。';

  @override
  String get privacyLogoutFailed => '退出登录或清理会话失败，当前页面仍被保护，请重试。';

  @override
  String get privacyLoginPreparationFailed => '历史登录状态清理失败，暂时无法进入登录页，请重试。';

  @override
  String get login => '登录';

  @override
  String get loginAgreementPrefix => '请同意';

  @override
  String get privacyAgreementName => '《隐私协议》';

  @override
  String get agreementAnd => '和';

  @override
  String get userAgreementName => '《用户协议》';

  @override
  String get account => '手机号/邮箱';

  @override
  String get password => '密码';

  @override
  String get enterAccount => '请输入手机号或邮箱';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get backHome => '返回首页';

  @override
  String get noData => '暂无数据';

  @override
  String get pageNotFound => '页面不存在';

  @override
  String get requestTimeout => '请求超时，请稍后重试';

  @override
  String get requestCanceled => '请求已取消';

  @override
  String get networkError => '网络连接异常';

  @override
  String get unknownError => '未知错误，请稍后重试';

  @override
  String get serverError => '服务器异常，请稍后重试';

  @override
  String get requestFailed => '请求失败，请稍后重试';

  @override
  String get sessionExpired => '登录状态已失效，请重新登录';

  @override
  String get permissionDenied => '暂无权限执行此操作';

  @override
  String get validationFailed => '提交内容校验失败';

  @override
  String get storageError => '本地数据处理失败';

  @override
  String get protocolError => '服务响应格式异常';

  @override
  String get networkDisconnected => '当前网络不可用，请检查网络设置';

  @override
  String get networkRestored => '网络连接已恢复';
}
