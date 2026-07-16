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

import '../localization/app_strings.dart';
import '../theme/app_spacing.dart';

/// 通用错误视图。
///
/// 展示错误图标、错误信息、和可选的重试按钮。
/// 通过 StateView 统一调用，业务页面不需要直接使用这个组件。
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  /// 最终展示给用户的错误文案。
  ///
  /// 调用方应传入本地固定文案，或由 FailureMessageResolver 筛选过的安全服务端文案；
  /// 不要直接传入 `error.toString()`，以免把接口地址、内部异常等技术细节暴露给用户。
  final String message;

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
              message.isEmpty ? AppStrings.requestFailed : message,
              textAlign: TextAlign.center,
            ),
            // 重试按钮：只在 onRetry 不为空时显示
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
