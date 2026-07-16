// lib/shared/ui/app_toast.dart
//
// 作用：提供类似 Android Toast 的页面级短提示。
//
// Toast 直接插入 MaterialApp/Navigator 的根 Overlay，不占 Scaffold 布局，也不进入
// ScaffoldMessenger 的 SnackBar 队列。默认在屏幕中部展示，并支持顶部、中部和底部。
// 它只负责短文案：不能点击、不要求用户确认、停留一小段时间后自动消失。

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Toast 在屏幕中的垂直位置。
enum AppToastPosition {
  /// 靠近安全区域顶部，适合网络变化等全局状态提示。
  top,

  /// 屏幕中部，最接近 Android Toast 的常见交互，也是默认位置。
  center,

  /// 靠近安全区域底部，但不会占用 Scaffold 的 SnackBar 通道。
  bottom,
}

/// Toast 的语义与视觉类型。
///
/// 类型只决定颜色和图标。ViewModel 仍然只发布普通消息或业务事件，不应导入本文件，
/// 否则状态层会反向依赖 Flutter View。
enum AppToastType {
  /// 普通说明，例如“已复制”。
  info,

  /// 操作成功，例如“保存成功”。
  success,

  /// 需要注意但尚未完全失败，例如检测到弱网。
  warning,

  /// 可恢复的操作失败，例如“请输入密码”。
  error,
}

/// App 公共 Toast 入口。
///
/// 与 SnackBar 的边界：
/// - Toast：短暂、不可操作、覆盖在页面上方，适合校验、成功和网络状态；
/// - SnackBar：固定在 Scaffold 底部，可以带“撤销/重试”等操作按钮；
/// - Dialog：必须让用户确认或做出选择；
/// - 页面内 ErrorView：错误需要持续存在，并且阻断当前页面内容。
///
/// 为什么没有引入第三方 Toast 包：Flutter 原生 [OverlayEntry] 已能实现定位、动画、
/// 主题和无障碍语义。自己封装没有平台通道初始化，不增加包体，也更容易在 Widget
/// 测试中验证。以后确有原生系统 Toast 要求时，只需替换本文件内部实现，调用方 API
/// 不需要变化。
abstract final class AppToast {
  /// 默认停留时间。
  static const duration = Duration(seconds: 2);

  /// 当前正在展示的 Toast。
  ///
  /// 全 App 同一时间只保留一个；新消息会替换旧消息，避免用户连续操作后堆积播放。
  static OverlayEntry? _activeEntry;

  /// 展示普通信息 Toast。
  static void showInfo(
    BuildContext context,
    String message, {
    AppToastPosition position = AppToastPosition.center,
    Duration displayDuration = duration,
    OverlayState? overlay,
  }) {
    show(
      context,
      message: message,
      position: position,
      displayDuration: displayDuration,
      overlay: overlay,
    );
  }

  /// 展示成功 Toast。
  static void showSuccess(
    BuildContext context,
    String message, {
    AppToastPosition position = AppToastPosition.center,
    Duration displayDuration = duration,
    OverlayState? overlay,
  }) {
    show(
      context,
      message: message,
      type: AppToastType.success,
      position: position,
      displayDuration: displayDuration,
      overlay: overlay,
    );
  }

  /// 展示警告 Toast。
  static void showWarning(
    BuildContext context,
    String message, {
    AppToastPosition position = AppToastPosition.center,
    Duration displayDuration = duration,
    OverlayState? overlay,
  }) {
    show(
      context,
      message: message,
      type: AppToastType.warning,
      position: position,
      displayDuration: displayDuration,
      overlay: overlay,
    );
  }

  /// 展示错误 Toast。
  static void showError(
    BuildContext context,
    String message, {
    AppToastPosition position = AppToastPosition.center,
    Duration displayDuration = duration,
    OverlayState? overlay,
  }) {
    show(
      context,
      message: message,
      type: AppToastType.error,
      position: position,
      displayDuration: displayDuration,
      overlay: overlay,
    );
  }

  /// 展示一条 Android 风格 Overlay Toast。
  ///
  /// 参数说明：
  /// - [context]：用于查找根 Overlay 和当前 Theme；必须来自仍然 mounted 的 View；
  /// - [message]：展示给用户的安全短文案；纯空白不会创建 Overlay；
  /// - [type]：决定颜色和图标；
  /// - [position]：顶部、中部或底部，默认居中；
  /// - [displayDuration]：完全展示后的停留时间，不包含约 160ms 的进出动画。
  /// - [overlay]：通常省略，由页面 context 自动查找；仅 MaterialApp.builder 等位于
  ///   Navigator 外层的 App 组合组件，才显式传根 NavigatorState.overlay。
  ///
  /// 找不到 Overlay 时方法安全返回，常见原因是 context 位于 MaterialApp 之外。
  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    AppToastPosition position = AppToastPosition.center,
    Duration displayDuration = duration,
    OverlayState? overlay,
  }) {
    final text = message.trim();
    if (text.isEmpty) return;
    if (displayDuration <= Duration.zero) {
      throw ArgumentError.value(displayDuration, 'displayDuration', '必须大于 0');
    }

    // rootOverlay: true 让 Toast 位于 GoRouter/Navigator 的页面之上。路由内部即使再有
    // 嵌套 Navigator，提示也不会被某个子页面裁剪或挡住。
    final targetOverlay =
        overlay ?? Overlay.maybeOf(context, rootOverlay: true);
    if (targetOverlay == null) return;
    final theme = Theme.of(context);

    // 替换旧提示采用立即移除；新提示自身仍有进入动画。这样快速连续校验时不会先
    // 等旧 Toast 退出 160ms，再延迟显示真正需要用户看到的新消息。
    dismiss();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return _AppToastOverlay(
          message: text,
          type: type,
          position: position,
          displayDuration: displayDuration,
          theme: theme,
          onDismissed: () {
            if (identical(_activeEntry, entry)) {
              _activeEntry = null;
            }
            if (entry.mounted) entry.remove();
          },
        );
      },
    );
    _activeEntry = entry;
    targetOverlay.insert(entry);
  }

  /// 立即关闭当前 Toast。
  ///
  /// 页面通常无需调用；新 Toast 和内部计时器会自动关闭。它主要用于退出特殊流程、
  /// Widget 测试 tearDown，或切换到必须立即显示的 Dialog 前清理轻提示。
  static void dismiss() {
    final entry = _activeEntry;
    _activeEntry = null;
    if (entry?.mounted ?? false) entry!.remove();
  }
}

/// 单条 Toast 的动画与自动关闭 Widget。
class _AppToastOverlay extends StatefulWidget {
  const _AppToastOverlay({
    required this.message,
    required this.type,
    required this.position,
    required this.displayDuration,
    required this.theme,
    required this.onDismissed,
  });

  final String message;
  final AppToastType type;
  final AppToastPosition position;
  final Duration displayDuration;
  final ThemeData theme;
  final VoidCallback onDismissed;

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 160);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _animationDuration,
    reverseDuration: _animationDuration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.94,
    end: 1,
  ).animate(_opacity);

  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.displayDuration, _closeWithAnimation);
  }

  Future<void> _closeWithAnimation() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;
    final (backgroundColor, foregroundColor, icon) = switch (widget.type) {
      AppToastType.info => (
        colorScheme.inverseSurface,
        colorScheme.onInverseSurface,
        Icons.info_outline,
      ),
      AppToastType.success => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      AppToastType.warning => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        Icons.wifi_tethering_error_rounded,
      ),
      AppToastType.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.error_outline,
      ),
    };

    final alignment = switch (widget.position) {
      AppToastPosition.top => Alignment.topCenter,
      AppToastPosition.center => Alignment.center,
      AppToastPosition.bottom => Alignment.bottomCenter,
    };

    // IgnorePointer 保证 Toast 不拦截页面点击；Semantics.liveRegion 让屏幕阅读器在提示
    // 出现时主动播报。SafeArea 避开刘海、状态栏和系统手势区域。
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          key: const ValueKey('app_toast_alignment'),
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: widget.message,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 20, color: foregroundColor),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: widget.theme.textTheme.bodyMedium
                                  ?.copyWith(color: foregroundColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
