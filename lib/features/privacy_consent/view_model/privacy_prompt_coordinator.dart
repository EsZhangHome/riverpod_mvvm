import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/privacy_consent_state.dart';
import '../model/privacy_prompt_state.dart';
import 'privacy_consent_view_model.dart';

/// 统一协调登录触发和升级场景弹窗的 Riverpod Provider。
///
/// PrivacyConsentHost 是唯一 Presenter；登录页只向这里发起请求并等待 bool 结果，
/// 不再自行调用 showDialog。这样多个登录入口与升级提示共享一条弹窗
/// 通道，不需要在两套 UI 生命周期之间同步 `_isShowing` 标志。
final class PrivacyPromptCoordinator extends Notifier<PrivacyPromptState> {
  Completer<bool>? _pendingLogin;
  int _nextRequestId = 0;

  @override
  PrivacyPromptState build() {
    ref.onDispose(() {
      final pending = _pendingLogin;
      if (pending != null && !pending.isCompleted) pending.complete(false);
      _pendingLogin = null;
    });
    return const PrivacyPromptState();
  }

  /// 登录页未勾选协议时，发起一次由根 Host 展示的显式确认请求。
  ///
  /// - 政策升级弹窗正由 Host 展示：立即 false，避免创建第二个弹窗；
  /// - 其他状态：发布一个显式请求，由同一个 Host 展示并等待结果；
  /// - 已有显式请求：后续并发调用立即 false，避免同意一次后重复发出多次登录。
  ///
  /// 即使磁盘中已经保存当前版本，这里也不会直接返回 true。因为调用本方法表示
  /// 登录页上的复选框此刻没有选中，用户需要在“本次登录界面”再次作出明确选择。
  /// 持久化记录和页面选择是两个不同事实，不能互相冒充。
  Future<bool> requestBeforeLogin() {
    final consent = ref.read(privacyConsentProvider);
    if (consent.status == PrivacyConsentStatus.policyUpgradeRequired) {
      return Future<bool>.value(false);
    }
    if (_pendingLogin != null || state.hasPendingRequest) {
      return Future<bool>.value(false);
    }

    final completer = Completer<bool>();
    _pendingLogin = completer;
    state = state.copyWith(
      requestId: ++_nextRequestId,
      reason: PrivacyPromptReason.loginRequired,
      declineFailed: false,
    );
    return completer.future;
  }

  /// 完成正在等待的登录门禁，并清除唯一弹窗请求。
  void resolveLoginRequest(bool accepted) {
    final pending = _pendingLogin;
    if (pending == null) return;
    _pendingLogin = null;
    state = state.copyWith(clearRequest: true, declineFailed: false);
    if (!pending.isCompleted) pending.complete(accepted);
  }

  /// 开始执行“拒绝升级 → 退出登录”的跨模块动作。
  bool beginDeclineAction() {
    if (state.isHandlingDecline) return false;
    state = state.copyWith(isHandlingDecline: true, declineFailed: false);
    return true;
  }

  /// 结束退出动作。失败时弹窗仍保持，用户可以明确重试或改为同意。
  void finishDeclineAction({required bool succeeded}) {
    state = state.copyWith(isHandlingDecline: false, declineFailed: !succeeded);
  }
}

final privacyPromptCoordinatorProvider =
    NotifierProvider<PrivacyPromptCoordinator, PrivacyPromptState>(
      PrivacyPromptCoordinator.new,
    );
