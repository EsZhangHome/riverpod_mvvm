// lib/shared/ui/app_snack_bar.dart
//
// 作用：统一展示位于页面底部、可以携带操作按钮的 SnackBar。
//
// 不要把它和 AppToast 混用：Toast 是不可点击的短提示；SnackBar 适合“已删除，撤销”
// 或“加载失败，重试”这类用户需要在几秒内执行后续操作的反馈。

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_toast.dart';

/// 公共 SnackBar 工具。
abstract final class AppSnackBar {
  /// SnackBar 默认比 Toast 停留更久，给用户阅读和点击操作按钮的时间。
  static const duration = Duration(seconds: 4);

  /// 展示底部 SnackBar。
  ///
  /// 参数说明：
  /// - [context]：必须位于 ScaffoldMessenger 下方；
  /// - [message]：安全、可直接展示的文案；
  /// - [type]：控制背景语义颜色，复用 Toast 的统一类型；
  /// - [actionLabel]/[onAction]：必须同时提供或同时省略，例如“撤销”及其回调；
  /// - [displayDuration]：停留时间；有操作时可按业务适当延长。
  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration displayDuration = duration,
  }) {
    final text = message.trim();
    if (text.isEmpty) return;
    if ((actionLabel == null) != (onAction == null)) {
      throw ArgumentError('actionLabel 和 onAction 必须同时提供或同时省略');
    }
    if (displayDuration <= Duration.zero) {
      throw ArgumentError.value(displayDuration, 'displayDuration', '必须大于 0');
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final colors = Theme.of(context).colorScheme;
    final (backgroundColor, foregroundColor) = switch (type) {
      AppToastType.info => (colors.inverseSurface, colors.onInverseSurface),
      AppToastType.success => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      AppToastType.warning => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      AppToastType.error => (colors.errorContainer, colors.onErrorContainer),
    };

    // 一个页面同一时间只保留一条业务操作反馈，新消息替换旧队列。
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: displayDuration,
          backgroundColor: backgroundColor,
          margin: const EdgeInsets.all(AppSpacing.lg),
          content: Text(text, style: TextStyle(color: foregroundColor)),
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: foregroundColor,
                  onPressed: onAction!,
                ),
        ),
      );
  }

  /// 立即关闭当前 SnackBar，包括正在进入/退出动画的那一条。
  static void dismiss(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }
}
