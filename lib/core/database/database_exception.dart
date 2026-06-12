// lib/core/database/database_exception.dart
//
// 作用：封装数据库异常。
//
// Repository 和 ViewModel 不需要知道 sqflite 的具体异常类型，
// 数据库层统一转换成 DatabaseException，后续排查问题也更清晰。

/// 数据库异常。
///
/// [message] 是给开发者看的错误描述。
/// [cause] 保存原始异常，方便日志系统记录真实原因。
/// [stackTrace] 保存原始堆栈，方便定位是哪一次数据库操作出错。
class DatabaseException implements Exception {
  const DatabaseException(this.message, {this.cause, this.stackTrace});

  /// 易读的错误消息。
  final String message;

  /// 原始异常对象。
  final Object? cause;

  /// 原始异常堆栈。
  final StackTrace? stackTrace;

  @override
  String toString() {
    if (cause == null) {
      return 'DatabaseException: $message';
    }
    return 'DatabaseException: $message, cause: $cause';
  }
}
