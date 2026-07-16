// 普通偏好、安全存储和数据库共同使用的稳定存储异常。
//
// 业务层不应该判断 MissingPluginException、PlatformException 或 sqflite 异常文本。
// 所有存储适配器在自己的边界保留原始 cause/stack，再统一抛出本类型或其子类型。

import 'app_failure.dart';

/// 本地持久化能力失败。
///
/// [message] 只能描述操作类型，不能包含 token、用户 JSON、SQL 参数等敏感数据。
/// ViewModel 不直接展示它，而是由 FailureMessageResolver 映射为本地化存储提示。
class StorageException extends AppFailure {
  const StorageException(this.message, {super.cause, super.stackTrace})
    : super(kind: FailureKind.storage, debugMessage: message);

  /// 供监控检索的稳定操作描述，例如“读取安全存储失败”。
  final String message;

  @override
  String toString() => 'StorageException: $message';
}
