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
  /// 创建稳定的数据库边界异常。
  ///
  /// [message] 描述正在执行的高层操作，例如“查询数据失败”；[cause] 和
  /// [stackTrace] 保存插件原始诊断信息。UI 只应依据 FailureMessageResolver 显示
  /// 通用存储错误，不能把本对象 toString 直接展示给用户。
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
