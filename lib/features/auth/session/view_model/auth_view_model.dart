// lib/features/auth/session/view_model/auth_view_model.dart
//
// App 级认证 ViewModel。它管理“恢复中、未登录、已登录”三种稳定状态，负责把
// 完整 AuthSession 交给 SessionStore，不直接操作 Keychain 或 SharedPreferences。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure_observer.dart';
import '../../../../core/utils/crash_reporter.dart';
import '../application/session_activator.dart';
import '../session_providers.dart';
import '../model/auth_session.dart';
import '../model/user_model.dart';

/// 认证状态机。显式枚举比多个 bool 更难组合出矛盾状态。
enum AuthStatus {
  /// App 启动后正在从安全存储读取会话；此时路由应等待，不能误跳登录页。
  restoring,

  /// 已确认本地没有有效会话，受保护路由应重定向到登录页。
  unauthenticated,

  /// 已存在完整会话，受保护路由可以进入。
  authenticated,
}

/// 全局认证状态（不可变）。
class AuthState {
  /// 创建“正在恢复会话”状态；session 固定为 null。
  const AuthState.restoring() : status = AuthStatus.restoring, session = null;

  /// 创建“未登录”状态；session 固定为 null。
  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      session = null;

  /// 创建“已登录”状态。
  ///
  /// [session] 必须包含同一次登录产生的非空 token 与用户信息。使用命名构造函数把
  /// status/session 的合法组合固定下来，调用方无法构造“authenticated 但无会话”。
  const AuthState.authenticated(AuthSession this.session)
    : status = AuthStatus.authenticated;

  /// 当前状态机阶段，路由守卫以它作为唯一判断来源。
  final AuthStatus status;

  /// 完整会话；只有 [AuthStatus.authenticated] 时非空。
  final AuthSession? session;

  /// 便捷读取 token。未登录或恢复中返回 null。
  String? get token => session?.token;

  /// 便捷读取当前用户。未登录或恢复中返回 null。
  UserModel? get currentUser => session?.user;

  /// 是否仍在启动恢复阶段。
  bool get isRestoringSession => status == AuthStatus.restoring;

  /// 是否处于内部一致的已登录状态；同时检查枚举和 session，避免异常数据漏过。
  bool get isLoggedIn => status == AuthStatus.authenticated && session != null;
}

/// App 级认证 ViewModel。
///
/// 状态更新规则：
/// - 恢复：安全存储完整解析成功才进入 authenticated；
/// - 登录：完整会话写入成功才更新内存状态；
/// - 刷新：新 token 持久化成功后才让请求重放；
/// - 退出：立即清内存，再尽力清安全存储并上报失败。
class AuthNotifier extends Notifier<AuthState> implements SessionActivator {
  /// 会话操作版本号。
  ///
  /// 每次恢复、登录、刷新或退出开始时都会捕获/递增版本。异步操作返回后如果版本
  /// 已变化，说明用户在等待期间执行了更新的会话命令，旧结果必须丢弃，不能重新
  /// 登录或覆盖新账号。
  int _sessionRevision = 0;

  /// 安全存储操作队列。
  ///
  /// Keychain/Keystore 的 write 与 clear 都是异步的。如果刷新写 token 和退出清理
  /// 并发执行，最终磁盘结果取决于插件完成顺序，而不是用户操作顺序。队列保证存储
  /// 修改严格按照命令入队顺序执行；内存状态仍可在 logout 时立即变成未登录。
  Future<void> _storageTail = Future<void>.value();

  /// 创建初始恢复状态，并把安全存储读取安排到当前同步构建结束后的微任务。
  ///
  /// `build` 不能标记 async，因为 AuthState 本身已经显式表示 restoring；如果改用
  /// AsyncNotifier，会同时出现 AsyncLoading 与 AuthStatus.restoring 两套加载语义。
  @override
  AuthState build() {
    Future.microtask(_restoreSession);
    return const AuthState.restoring();
  }

  /// 刷新并原子保存新会话，供 App 组合层的网络绑定调用。
  ///
  /// ViewModel 只依赖 SessionRefresher 和 SessionStore 两个认证领域端口，不知道
  /// Dio、拦截器或请求重放细节。保存失败时返回 null，网络层会按刷新失败处理。
  ///
  /// 返回值：新 token 表示刷新且持久化均成功；null 可能表示当前未登录、刷新服务
  /// 拒绝恢复、Provider 已销毁或安全存储失败。网络层不需要区分这些内部原因，都会
  /// 终止当前请求的自动重放并进入统一会话失效策略。
  Future<String?> refreshAccessToken() async {
    final current = state.session;
    if (current == null) return null;
    final revision = ++_sessionRevision;
    // 在命令发起时固定依赖实例，避免测试/项目组合层在等待刷新接口期间替换
    // sessionStoreProvider，导致同一个会话命令跨两个存储实现执行。
    final store = ref.read(sessionStoreProvider);
    String? token;
    try {
      token = await ref.read(sessionRefresherProvider).refreshAccessToken();
    } catch (error, stack) {
      // 刷新接口失败是可恢复的认证结果：保留原始异常分类用于观察，但向网络层只
      // 返回 null，由 401 协调器统一执行会话失效流程。
      FailureObserver.reportIfNeeded(error, stack);
      return null;
    }
    if (token == null ||
        token.isEmpty ||
        !ref.mounted ||
        revision != _sessionRevision ||
        !identical(state.session, current)) {
      return null;
    }

    final refreshed = AuthSession(token: token, user: current.user);
    try {
      return await _runStorageOperation(() async {
        // 操作真正轮到安全存储时再检查一次。等待前面写入期间可能已经 logout 或
        // 切换账号，过期刷新不得再触碰磁盘。
        if (!ref.mounted ||
            revision != _sessionRevision ||
            !identical(state.session, current)) {
          return null;
        }
        await store.write(refreshed);
        if (!ref.mounted || revision != _sessionRevision) return null;
        state = AuthState.authenticated(refreshed);
        return token;
      });
    } catch (error, stack) {
      FailureObserver.reportIfNeeded(error, stack);
      return null;
    }
  }

  Future<void> _restoreSession() async {
    final revision = _sessionRevision;
    final store = ref.read(sessionStoreProvider);
    try {
      final session = await _runStorageOperation(store.read);
      if (!ref.mounted || revision != _sessionRevision) return;
      if (session == null) {
        state = const AuthState.unauthenticated();
        return;
      }
      state = AuthState.authenticated(session);
      CrashReporter.setContext('userId', session.user.id);
    } catch (error, stack) {
      // 损坏或旧版本会话不能继续使用。先尝试清除，避免每次启动重复解析失败。
      FailureObserver.reportIfNeeded(error, stack);
      try {
        await _runStorageOperation(() async {
          // 恢复失败后若用户已经开始了新的登录/退出命令，不能用旧清理动作删除
          // 新会话；更新命令会自行写入或清理正确状态。
          if (revision == _sessionRevision) await store.clear();
        });
      } catch (clearError, clearStack) {
        FailureObserver.reportIfNeeded(clearError, clearStack);
      }
      // 读取失败只是 revision 对应的旧恢复命令的结论。如果等待清理期间用户已经
      // 完成新登录，不能在最后一步再用旧结论覆盖刚发布的新会话。
      if (ref.mounted && revision == _sessionRevision) {
        state = const AuthState.unauthenticated();
      }
    }
  }

  /// 保存登录成功得到的完整会话。
  ///
  /// [session] 已由登录用例将同一次响应中的 token 与用户组合完成。本方法只负责
  /// 会话生命周期：先持久化，成功后再发布 AuthState。
  ///
  /// 只有安全存储写入成功且 Provider 仍存活时才更新 state，并返回 true。false 表示
  /// 会话没有可靠保存，调用方应留在登录页并展示错误，不能先跳首页再补写凭据。
  @override
  Future<bool> activateSession(AuthSession session) async {
    final revision = ++_sessionRevision;
    final store = ref.read(sessionStoreProvider);
    try {
      return await _runStorageOperation(() async {
        if (!ref.mounted || revision != _sessionRevision) return false;
        await store.write(session);
        if (!ref.mounted || revision != _sessionRevision) return false;

        state = AuthState.authenticated(session);
        CrashReporter.setContext('userId', session.user.id);
        return true;
      });
    } catch (error, stack) {
      FailureObserver.reportIfNeeded(error, stack);
      return false;
    }
  }

  /// 清理登录态。内存立即退出，安全存储失败会重试一次。
  ///
  /// 本方法没有 BuildContext，也不显式导航。state 改成 unauthenticated 后，AppRouter
  /// 的 refreshListenable 会重新执行 AuthRouteGuard，当前受保护页面自然回到登录页。
  /// [requirePersistentClear] 默认 false，适合普通退出和 401：即使设备存储暂时故障，
  /// 当前进程也必须先退出，最终失败由监控记录。隐私政策升级拒绝必须传 true；两次
  /// 清理都失败时重新抛出，让全局协议弹窗继续遮挡页面，不能误报“已安全退出”。
  Future<void> logout({bool requirePersistentClear = false}) async {
    ++_sessionRevision;
    state = const AuthState.unauthenticated();
    CrashReporter.setContext('userId', null);
    final store = ref.read(sessionStoreProvider);
    Object? finalError;
    StackTrace? finalStack;

    await _runStorageOperation(() async {
      try {
        await store.clear();
        return;
      } catch (error, stack) {
        finalError = error;
        finalStack = stack;
      }
      try {
        await store.clear();
        finalError = null;
        finalStack = null;
      } catch (retryError, retryStack) {
        finalError = retryError;
        finalStack = retryStack;
      }
    });

    if (finalError == null) return;
    if (requirePersistentClear) {
      // 严格模式交给调用方统一上报并决定 UI 是否继续阻断。这里不重复上报，否则
      // 同一个 Keychain/Keystore 故障会被 Auth 与隐私 Presenter 各记一遍。
      Error.throwWithStackTrace(finalError!, finalStack!);
    }
    // 普通退出无需让 UI 等待或失败，但两次都清不掉的最终异常必须进入统一观察链。
    // 第一次失败、第二次成功属于已恢复瞬态故障，不制造无意义告警。
    FailureObserver.reportIfNeeded(finalError!, finalStack!);
  }

  /// 把一次安全存储操作接到队尾，并把自己的结果/异常返回给调用方。
  ///
  /// 队尾 Future 永远被内部消费，不会因为前一项失败而让后续清理永久跳过；真正的
  /// 异常通过当前操作自己的 Completer 交还给对应命令处理。
  Future<T> _runStorageOperation<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _storageTail = _storageTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// 用户级缓存只依赖用户 id；刷新 token 不会让购物车、收藏等状态重建。
///
/// `select` 只订阅 `currentUser?.id` 这一小段状态：刷新 token 时 AuthState 虽然变化，
/// 但 id 不变，依赖此 Provider 的用户级业务不会无意义重建。退出/切换用户时 id
/// 变化，相关 Provider 才应该清空或重新加载数据。
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider.select((state) => state.currentUser?.id));
});
