// lib/shared/ui/error_view.dart
//
// 作用：通用错误视图，展示错误提示和可选的重试按钮。
//
// 显示时机：
// - 网络请求失败时
// - 业务异常时（如账号冻结、权限不足）
// - 数据解析失败时
//
// 交互逻辑：
// - 如果 onRetry 不为空，显示重试按钮，用户点击后重新发起请求
// - 如果 onRetry 为空，只展示错误信息，不显示按钮
//   （某些不可重试的错误，如"账号已被冻结"，不需要重试按钮）

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../localization/user_message.dart';
import '../theme/app_spacing.dart';

/// 通用错误视图。
///
/// 展示错误图标、错误信息、和可选的重试按钮。
/// 通过 StateView 统一调用，业务页面不需要直接使用这个组件。
class ErrorView extends StatelessWidget {
  /// 创建错误状态视图。
  ///
  /// - [message]：经过 FailureMessageResolver 筛选的类型化安全消息；为 null 时使用
  ///   当前语言的通用“请求失败”提示；
  /// - [onRetry]：可选同步点击回调。为 null 时不显示按钮；传入时通常调用
  ///   `ref.read(xxxProvider.notifier).reload()`，不要在 Widget 内复制请求逻辑；
  /// - [key]：可选 Widget 身份键，通常无需业务手工提供。
  const ErrorView({super.key, this.message, this.onRetry});

  /// 等待当前 View 按 Locale 解析的错误消息。
  ///
  /// 固定提示使用 `UserMessage.localized`，可信动态业务文案使用 `UserMessage.text`。
  /// 不要把 `error.toString()` 包装进来，以免暴露接口地址、内部异常等技术细节。
  final UserMessage? message;

  /// 重试回调，为 null 时不显示重试按钮
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          // 最小尺寸，内容居中
          mainAxisSize: MainAxisSize.min,
          children: [
            // 错误图标：红色感叹号，让用户快速识别当前是失败状态
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            // 错误信息文本
            // 如果 message 为空，使用默认的"请求失败"提示
            Text(
              (message ??
                      const UserMessage.localized(UserMessageKey.requestFailed))
                  .resolve(AppLocalizations.of(context)),
              textAlign: TextAlign.center,
            ),
            // 重试按钮：只在 onRetry 不为空时显示
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
