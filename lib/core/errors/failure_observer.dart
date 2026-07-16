// 对已经捕获的失败执行统一监控策略。
//
// 状态处理器不应该分别猜测哪些异常需要上报，否则同一种协议错误可能在列表页被
// 上报、在表单页却被忽略。本类只负责可观测性，不负责生成 UI 文案或改变状态。

import '../utils/crash_reporter.dart';
import 'app_failure.dart';

/// 把异常分类策略翻译成一次安全的 CrashReporter 调用。
abstract final class FailureObserver {
  /// 上报非预期失败；可预期业务失败保持静默。
  ///
  /// [fallbackStackTrace] 是当前 catch 得到的堆栈。AppFailure 如果保存了更接近根因
  /// 的 [AppFailure.stackTrace]，优先使用它；如果保存了原始 [AppFailure.cause]，
  /// 上报 cause 而不是包装对象，让监控平台按真正异常类型聚合。
  static void reportIfNeeded(Object error, StackTrace fallbackStackTrace) {
    if (error is AppFailure) {
      if (!error.shouldReport) return;
      CrashReporter.report(
        error.cause ?? error,
        error.stackTrace ?? fallbackStackTrace,
      );
      return;
    }
    CrashReporter.report(error, fallbackStackTrace);
  }
}
