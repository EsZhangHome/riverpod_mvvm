// lib/shared/errors/failure_message_resolver.dart
//
// 这是 Core 异常与 UI 文案之间的翻译边界。网络层只抛 FailureKind，避免依赖
// 中文或 BuildContext；ViewModel 调用这里得到可安全展示的提示。以后全面迁移
// ARB 时，只需替换本 Resolver 的文案来源，不需要修改 ApiClient。

import '../../core/errors/app_failure.dart';
import '../../core/network/api_exception.dart';
import '../localization/app_strings.dart';

/// 把底层异常翻译为可以安全展示给用户的文案。
///
/// `abstract final` 表示它只是静态工具命名空间；页面和 ViewModel 不需要创建实例。
abstract final class FailureMessageResolver {
  static String resolve(Object error) {
    // BusinessException 的文案由业务后端明确返回，允许优先展示；普通 HTTP 500
    // 的 message 可能包含网关或数据库信息，不能走这个分支直接泄露给用户。
    if (error is BusinessException && error.canDisplayMessage) {
      return error.userMessage;
    }
    if (error is AppFailure) {
      // suggestedMessage 只给调用方确认过安全的领域失败使用。
      final explicit = error.suggestedMessage;
      if (explicit != null && explicit.isNotEmpty) return explicit;
      return switch (error.kind) {
        FailureKind.network => AppStrings.networkError,
        FailureKind.timeout => AppStrings.requestTimeout,
        FailureKind.server => AppStrings.serverError,
        FailureKind.authentication => AppStrings.sessionExpired,
        FailureKind.permission => AppStrings.permissionDenied,
        FailureKind.validation => AppStrings.validationFailed,
        FailureKind.business => AppStrings.requestFailed,
        FailureKind.storage => AppStrings.storageError,
        FailureKind.cancellation => AppStrings.requestCanceled,
        FailureKind.protocol => AppStrings.protocolError,
        FailureKind.unknown => AppStrings.unknownError,
      };
    }
    // 非 AppFailure 可能是编程错误或未知三方异常，统一使用兜底文案，
    // 真正异常仍由日志/CrashReporter 保存，不能把 error.toString() 展示出去。
    return AppStrings.requestFailed;
  }
}
