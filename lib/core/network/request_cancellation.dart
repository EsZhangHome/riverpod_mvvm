// lib/core/network/request_cancellation.dart
//
// 作用：定义与具体网络库无关的“请求取消”和“传输进度”类型。
//
// 为什么不让 Repository 直接使用 Dio 的 CancelToken：
// - Repository、UseCase 和 ViewModel 属于业务代码，不应该知道底层使用了 Dio；
// - 如果以后替换网络库，业务层的方法签名不应被迫一起修改；
// - 单元测试只需要一个普通 Dart 对象，不必为了模拟取消行为引入 Dio。
//
// Dio 的适配只发生在 ApiClient 内部：ApiClient 观察本令牌的 whenCancelled，
// 再取消自己创建的 Dio CancelToken。因此“谁发起取消”与“底层怎样取消 IO”被解耦。

import 'dart:async';

import '../errors/app_failure.dart';

/// 非 HTTP 数据源在收到取消信号后可以抛出的稳定失败。
///
/// ApiClient 会把 Dio 的取消异常转换成同一 [FailureKind.cancellation]；本类型主要
/// 给 Mock Repository、本地计算或其他可取消 Future 使用，让上层只判断 AppFailure，
/// 不需要认识某个第三方库的异常。
final class RequestCancellationFailure extends AppFailure {
  const RequestCancellationFailure([Object? reason])
    : super(
        kind: FailureKind.cancellation,
        debugMessage: 'Request was cancelled',
        cause: reason,
      );
}

/// 一次异步请求的取消令牌。
///
/// 典型生命周期：
/// 1. ViewModel 的请求协调器在发请求前创建令牌；
/// 2. 同一个令牌依次传给 UseCase、Repository 和 [ApiService]；
/// 3. Provider 销毁、用户返回或新请求替代旧请求时调用 [cancel]；
/// 4. ApiClient 把取消信号转交给具体网络库，尽早停止 socket、下载或 JSON 解析；
/// 5. 即使某个数据源无法真正取消，ViewModel 仍通过 [isCancelled] 阻止旧结果回写。
///
/// 本类故意不是全局单例。一个令牌只代表“一次请求”，多个并发请求必须使用不同
/// 实例，否则取消其中一个请求会误伤其他请求。
final class RequestCancellationToken {
  /// 创建一个尚未取消的令牌。
  RequestCancellationToken();

  /// 首次取消时完成的 Completer。
  ///
  /// 使用 Future 而不是依赖 Flutter 的 ChangeNotifier，是为了让该类型保持纯 Dart，
  /// 可以在 Repository、后台任务和单元测试中使用。
  final Completer<Object?> _cancellation = Completer<Object?>();

  /// 当前仍在等待取消信号的基础设施监听者。
  ///
  /// ApiClient 会在请求完成后主动移除自己的监听，避免一个长生命周期页面连续请求
  /// 时积累已经没有用途的底层网络令牌。
  final Set<void Function(Object? reason)> _listeners = {};

  /// 首次取消时记录的原因，仅用于调试和日志上下文。
  ///
  /// 原因可能包含页面名称等内部信息，不应直接作为面向用户的错误文案展示。
  Object? _reason;

  /// 是否已经收到取消信号。
  ///
  /// 取消是不可逆的：一旦为 true，该令牌不能复用；下一次请求应创建新令牌。
  bool get isCancelled => _cancellation.isCompleted;

  /// 首次调用 [cancel] 时传入的原因；尚未取消时为 null。
  Object? get reason => _reason;

  /// 在令牌取消时完成的 Future，完成值是 [reason]。
  ///
  /// 网络库适配器可以监听它并取消底层 IO；测试 Fake 也可以 `await` 它来模拟一个
  /// 一直执行、直到页面销毁才结束的请求。
  Future<Object?> get whenCancelled => _cancellation.future;

  /// 监听取消信号，并返回一个可解除监听的注册对象。
  ///
  /// 该能力主要给网络库适配器使用。若令牌已经取消，[listener] 会立刻收到第一次
  /// 取消原因；返回的 registration 仍可安全 dispose。业务层一般只需调用 [cancel]。
  RequestCancellationRegistration listen(
    void Function(Object? reason) listener,
  ) {
    if (isCancelled) {
      listener(_reason);
      return const RequestCancellationRegistration._();
    }
    _listeners.add(listener);
    return RequestCancellationRegistration._(() => _listeners.remove(listener));
  }

  /// 发出取消信号。
  ///
  /// [reason] 是可选的诊断信息，例如 `provider disposed`。本方法是幂等的：重复
  /// 调用不会抛异常，也不会覆盖第一次的原因，方便 refresh 和 dispose 都安全调用。
  void cancel([Object? reason]) {
    if (isCancelled) return;
    _reason = reason;
    _cancellation.complete(reason);
    final listeners = _listeners.toList(growable: false);
    _listeners.clear();
    for (final listener in listeners) {
      listener(reason);
    }
  }
}

/// 一次取消监听注册。
///
/// [dispose] 只解除监听，不会取消请求本身。本类由 ApiClient 在 HTTP 请求结束后调用，
/// 一般业务代码不需要保存它。
final class RequestCancellationRegistration {
  const RequestCancellationRegistration._([this._remove]);

  final void Function()? _remove;

  /// 解除监听。令牌已经取消并清空监听时调用也没有副作用。
  void dispose() => _remove?.call();
}

/// 上传或下载进度回调。
///
/// [transferredBytes] 是已经传输的字节数；[totalBytes] 是服务端或本地文件报告的
/// 总字节数。部分响应无法提前得知总大小，此时 totalBytes 可能小于等于 0，UI 应
/// 展示不确定进度指示器，而不是直接执行除法。
typedef RequestProgressCallback =
    void Function(int transferredBytes, int totalBytes);
