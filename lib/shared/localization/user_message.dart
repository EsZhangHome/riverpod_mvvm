// 面向最终用户的一次提示，不保存已经翻译好的固定语言字符串。
//
// 为什么 ViewModel 不直接保存“请求失败，请重试”：
// ViewModel 没有 BuildContext，无法知道用户当前选择的是中文还是英文。如果它提前把
// 错误变成中文 String，View 即使处在英文 Locale 下也只能显示中文。这里改为保存稳定
// 的消息键，直到 View 真正展示时再使用 AppLocalizations 解析当前语言。

import '../../l10n/app_localizations.dart';

/// 底座内置、可以通过 ARB 翻译的用户消息键。
///
/// 枚举值是 ViewModel 与 View 之间的稳定契约；中文、英文等实际文案分别保存在
/// `lib/l10n/app_zh.arb` 与 `app_en.arb`。新增一种固定提示时，需要同时：
/// 1. 在这里增加枚举值；
/// 2. 在所有 ARB 文件增加同名文案；
/// 3. 在 [UserMessage.resolve] 的 switch 中建立映射。
enum UserMessageKey {
  enterAccountAndPassword,
  enterAccount,
  enterPassword,
  requestTimeout,
  requestCanceled,
  networkError,
  unknownError,
  serverError,
  requestFailed,
  sessionExpired,
  permissionDenied,
  validationFailed,
  storageError,
  protocolError,
}

/// ViewModel 可以安全交给 View 的类型化用户消息。
///
/// 消息有两种来源：
/// - [UserMessage.localized]：底座已知的固定提示，只保存 [UserMessageKey]；
/// - [UserMessage.text]：后端明确标记为可展示的动态业务提示，例如“账号已冻结”。
///
/// `text` 不是给任意异常开放的逃生口。`error.toString()`、URL、堆栈、数据库信息等
/// 技术细节不能放进来；它们应进入日志或 CrashReporter。
final class UserMessage {
  /// 创建一个等待 View 按当前 Locale 翻译的固定消息。
  const UserMessage.localized(UserMessageKey key) : _key = key, _text = null;

  /// 创建一个已经由可信业务边界确认可展示的动态消息。
  const UserMessage.text(String text)
    : assert(text != '', '可展示的动态消息不能为空'),
      _key = null,
      _text = text;

  final UserMessageKey? _key;
  final String? _text;

  /// 固定消息的键；动态业务文案时为 null。主要供测试和诊断使用。
  UserMessageKey? get key => _key;

  /// 可信的动态业务文案；固定消息时为 null。主要供测试和诊断使用。
  String? get text => _text;

  /// 使用当前 Widget 树中的本地化对象得到最终展示字符串。
  ///
  /// [strings] 必须由 View 通过 `AppLocalizations.of(context)` 获取。ViewModel、
  /// Repository 和网络层都不应为了调用本方法而持有 BuildContext。
  String resolve(AppLocalizations strings) {
    final text = _text;
    if (text != null) return text;

    return switch (_key!) {
      UserMessageKey.enterAccountAndPassword => strings.enterAccountAndPassword,
      UserMessageKey.enterAccount => strings.enterAccount,
      UserMessageKey.enterPassword => strings.enterPassword,
      UserMessageKey.requestTimeout => strings.requestTimeout,
      UserMessageKey.requestCanceled => strings.requestCanceled,
      UserMessageKey.networkError => strings.networkError,
      UserMessageKey.unknownError => strings.unknownError,
      UserMessageKey.serverError => strings.serverError,
      UserMessageKey.requestFailed => strings.requestFailed,
      UserMessageKey.sessionExpired => strings.sessionExpired,
      UserMessageKey.permissionDenied => strings.permissionDenied,
      UserMessageKey.validationFailed => strings.validationFailed,
      UserMessageKey.storageError => strings.storageError,
      UserMessageKey.protocolError => strings.protocolError,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is UserMessage && other._key == _key && other._text == _text;
  }

  @override
  int get hashCode => Object.hash(_key, _text);

  @override
  String toString() => _text ?? 'UserMessage.${_key!.name}';
}
