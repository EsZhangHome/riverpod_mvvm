import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @initializationFailed.
  ///
  /// In zh, this message translates to:
  /// **'应用初始化失败'**
  String get initializationFailed;

  /// No description provided for @failedStages.
  ///
  /// In zh, this message translates to:
  /// **'失败阶段：{stages}'**
  String failedStages(String stages);

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @privacyConsentTitle.
  ///
  /// In zh, this message translates to:
  /// **'协议与隐私保护说明'**
  String get privacyConsentTitle;

  /// No description provided for @privacyInitialConsentIntroduction.
  ///
  /// In zh, this message translates to:
  /// **'首次使用前，请阅读隐私协议和用户协议。同意后会选中登录页协议选项；不同意只关闭本次弹窗并停留在登录页，不会发送登录请求。下次启动仍会再次提示。'**
  String get privacyInitialConsentIntroduction;

  /// No description provided for @privacyLoginConsentIntroduction.
  ///
  /// In zh, this message translates to:
  /// **'登录前需要你阅读并同意隐私协议和用户协议。同意后会选中登录页协议选项；账号密码已填写时继续登录，未填写时只选中协议，不显示输入提示。不同意则取消选中并停留在登录页。'**
  String get privacyLoginConsentIntroduction;

  /// No description provided for @privacyPolicyUpgradeTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策已更新'**
  String get privacyPolicyUpgradeTitle;

  /// No description provided for @privacyPolicyUpgradeIntroduction.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策内容或版本已更新，请阅读后选择。同意后继续停留在当前页面；不同意将退出当前账号并返回登录页面。下次启动时仍会再次提示。'**
  String get privacyPolicyUpgradeIntroduction;

  /// No description provided for @privacyPolicyUpgradeLoginIntroduction.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策已经更新。重新登录前请阅读并确认；同意后继续本次登录，不同意则关闭弹窗并停留在登录页。'**
  String get privacyPolicyUpgradeLoginIntroduction;

  /// No description provided for @privacyConsentVersion.
  ///
  /// In zh, this message translates to:
  /// **'授权版本：{version}'**
  String privacyConsentVersion(String version);

  /// No description provided for @privacyDocumentVersion.
  ///
  /// In zh, this message translates to:
  /// **'政策文档版本：{version}'**
  String privacyDocumentVersion(String version);

  /// No description provided for @userAgreementDocumentVersion.
  ///
  /// In zh, this message translates to:
  /// **'用户协议文档版本：{version}'**
  String userAgreementDocumentVersion(String version);

  /// No description provided for @privacyPolicyAddress.
  ///
  /// In zh, this message translates to:
  /// **'完整隐私政策地址'**
  String get privacyPolicyAddress;

  /// No description provided for @viewFullPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'阅读完整隐私政策'**
  String get viewFullPrivacyPolicy;

  /// No description provided for @viewFullUserAgreement.
  ///
  /// In zh, this message translates to:
  /// **'阅读完整用户协议'**
  String get viewFullUserAgreement;

  /// No description provided for @privacyPolicyOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法打开协议页面，请检查系统浏览器或网络后重试。'**
  String get privacyPolicyOpenFailed;

  /// No description provided for @privacyDisclosureDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'处理哪些信息'**
  String get privacyDisclosureDataTitle;

  /// No description provided for @privacyDisclosureDataBody.
  ///
  /// In zh, this message translates to:
  /// **'登录时处理你主动填写的账号和密码；具体业务需要其他信息时，必须在使用对应功能前另行说明。'**
  String get privacyDisclosureDataBody;

  /// No description provided for @privacyDisclosurePurposeTitle.
  ///
  /// In zh, this message translates to:
  /// **'为什么处理'**
  String get privacyDisclosurePurposeTitle;

  /// No description provided for @privacyDisclosurePurposeBody.
  ///
  /// In zh, this message translates to:
  /// **'用于身份验证、维护登录状态和保障账号安全，不应超出实现当前功能所必需的范围。'**
  String get privacyDisclosurePurposeBody;

  /// No description provided for @privacyDisclosureThirdPartyTitle.
  ///
  /// In zh, this message translates to:
  /// **'权限与第三方'**
  String get privacyDisclosureThirdPartyTitle;

  /// No description provided for @privacyDisclosureThirdPartyBody.
  ///
  /// In zh, this message translates to:
  /// **'同意前不会启动需要授权的延迟能力；正式项目必须在完整政策中逐项列明实际权限、SDK、共享数据和用途。'**
  String get privacyDisclosureThirdPartyBody;

  /// No description provided for @privacyDisclosureRightsTitle.
  ///
  /// In zh, this message translates to:
  /// **'你的选择和权利'**
  String get privacyDisclosureRightsTitle;

  /// No description provided for @privacyDisclosureRightsBody.
  ///
  /// In zh, this message translates to:
  /// **'你可以拒绝并停留在登录页。正式项目还必须提供撤回同意、更正、删除、注销账号和投诉渠道。'**
  String get privacyDisclosureRightsBody;

  /// No description provided for @agreeAndContinue.
  ///
  /// In zh, this message translates to:
  /// **'同意并继续'**
  String get agreeAndContinue;

  /// No description provided for @agreeAndContinueUsing.
  ///
  /// In zh, this message translates to:
  /// **'同意并继续使用'**
  String get agreeAndContinueUsing;

  /// No description provided for @declineAndLogout.
  ///
  /// In zh, this message translates to:
  /// **'不同意并退出登录'**
  String get declineAndLogout;

  /// No description provided for @disagree.
  ///
  /// In zh, this message translates to:
  /// **'不同意'**
  String get disagree;

  /// No description provided for @privacyConsentSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'同意状态保存失败，登录请求尚未发出，请重试。'**
  String get privacyConsentSaveFailed;

  /// No description provided for @privacyLogoutFailed.
  ///
  /// In zh, this message translates to:
  /// **'退出登录或清理会话失败，当前页面仍被保护，请重试。'**
  String get privacyLogoutFailed;

  /// No description provided for @privacyLoginPreparationFailed.
  ///
  /// In zh, this message translates to:
  /// **'历史登录状态清理失败，暂时无法进入登录页，请重试。'**
  String get privacyLoginPreparationFailed;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @loginAgreementPrefix.
  ///
  /// In zh, this message translates to:
  /// **'请同意'**
  String get loginAgreementPrefix;

  /// No description provided for @privacyAgreementName.
  ///
  /// In zh, this message translates to:
  /// **'《隐私协议》'**
  String get privacyAgreementName;

  /// No description provided for @agreementAnd.
  ///
  /// In zh, this message translates to:
  /// **'和'**
  String get agreementAnd;

  /// No description provided for @userAgreementName.
  ///
  /// In zh, this message translates to:
  /// **'《用户协议》'**
  String get userAgreementName;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'手机号/邮箱'**
  String get account;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @enterAccount.
  ///
  /// In zh, this message translates to:
  /// **'请输入手机号或邮箱'**
  String get enterAccount;

  /// No description provided for @enterPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get enterPassword;

  /// No description provided for @backHome.
  ///
  /// In zh, this message translates to:
  /// **'返回首页'**
  String get backHome;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @pageNotFound.
  ///
  /// In zh, this message translates to:
  /// **'页面不存在'**
  String get pageNotFound;

  /// No description provided for @requestTimeout.
  ///
  /// In zh, this message translates to:
  /// **'请求超时，请稍后重试'**
  String get requestTimeout;

  /// No description provided for @requestCanceled.
  ///
  /// In zh, this message translates to:
  /// **'请求已取消'**
  String get requestCanceled;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络连接异常'**
  String get networkError;

  /// No description provided for @unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误，请稍后重试'**
  String get unknownError;

  /// No description provided for @serverError.
  ///
  /// In zh, this message translates to:
  /// **'服务器异常，请稍后重试'**
  String get serverError;

  /// No description provided for @requestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求失败，请稍后重试'**
  String get requestFailed;

  /// No description provided for @sessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录状态已失效，请重新登录'**
  String get sessionExpired;

  /// No description provided for @permissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'暂无权限执行此操作'**
  String get permissionDenied;

  /// No description provided for @validationFailed.
  ///
  /// In zh, this message translates to:
  /// **'提交内容校验失败'**
  String get validationFailed;

  /// No description provided for @storageError.
  ///
  /// In zh, this message translates to:
  /// **'本地数据处理失败'**
  String get storageError;

  /// No description provided for @protocolError.
  ///
  /// In zh, this message translates to:
  /// **'服务响应格式异常'**
  String get protocolError;

  /// No description provided for @networkDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'当前网络不可用，请检查网络设置'**
  String get networkDisconnected;

  /// No description provided for @networkRestored.
  ///
  /// In zh, this message translates to:
  /// **'网络连接已恢复'**
  String get networkRestored;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
