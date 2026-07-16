// lib/shared/errors/failure_message_resolver.dart
//
// 这是 Core 异常与用户消息之间的翻译边界。网络层只抛 FailureKind，避免依赖
// Flutter UI 或具体语言；ViewModel 调用这里得到 UserMessage，View 再按当前 Locale
// 解析最终文案。

import '../../core/errors/app_failure.dart';
import '../../core/network/api_exception.dart';
import '../localization/user_message.dart';

/// 把底层异常翻译为可以安全展示给用户的文案。
///
/// `abstract final` 表示它只是静态工具命名空间；页面和 ViewModel 不需要创建实例。
abstract final class FailureMessageResolver {
  /// 把任意 [error] 转为安全、可本地化的类型化消息。
  ///
  /// 返回规则按优先级执行：可信业务文案 → AppFailure 建议文案 → FailureKind 固定文案
  /// → 未知异常兜底文案。方法绝不会把 `error.toString()`、URL、响应体或堆栈返回给
  /// View。技术细节应由请求边界上报 CrashReporter，而不是显示在页面上。
  static UserMessage resolve(Object error) {
    // BusinessException 的文案由业务后端明确返回，允许优先展示；普通 HTTP 500
    // 的 message 可能包含网关或数据库信息，不能走这个分支直接泄露给用户。
    if (error is BusinessException && error.canDisplayMessage) {
      return UserMessage.text(error.userMessage);
    }
    if (error is AppFailure) {
      // suggestedMessage 只给调用方确认过安全的领域失败使用。
      final explicit = error.suggestedMessage;
      if (explicit != null && explicit.isNotEmpty) {
        return UserMessage.text(explicit);
      }
      return switch (error.kind) {
        FailureKind.network => const UserMessage.localized(
          UserMessageKey.networkError,
        ),
        FailureKind.timeout => const UserMessage.localized(
          UserMessageKey.requestTimeout,
        ),
        FailureKind.server => const UserMessage.localized(
          UserMessageKey.serverError,
        ),
        FailureKind.authentication => const UserMessage.localized(
          UserMessageKey.sessionExpired,
        ),
        FailureKind.permission => const UserMessage.localized(
          UserMessageKey.permissionDenied,
        ),
        FailureKind.validation => const UserMessage.localized(
          UserMessageKey.validationFailed,
        ),
        FailureKind.business => const UserMessage.localized(
          UserMessageKey.requestFailed,
        ),
        FailureKind.storage => const UserMessage.localized(
          UserMessageKey.storageError,
        ),
        FailureKind.cancellation => const UserMessage.localized(
          UserMessageKey.requestCanceled,
        ),
        FailureKind.protocol => const UserMessage.localized(
          UserMessageKey.protocolError,
        ),
        FailureKind.unknown => const UserMessage.localized(
          UserMessageKey.unknownError,
        ),
      };
    }
    // 非 AppFailure 可能是编程错误或未知三方异常，统一使用兜底文案，
    // 真正异常仍由日志/CrashReporter 保存，不能把 error.toString() 展示出去。
    return const UserMessage.localized(UserMessageKey.requestFailed);
  }
}
