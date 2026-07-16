// Starter 组件自己的最小中英文文案。
//
// 这些文字不能放进根 lib/l10n/*.arb：真实项目删除 Starter 目录后，全局生成的
// AppLocalizations 仍会残留 starterMessage 等字段。把占位文案留在组件内部，删除
// 目录时源码、路由、页面和文案会一起消失。

import 'package:flutter/widgets.dart';

/// 根据当前 Locale 提供 Starter 占位文案。
///
/// Starter 只有两个短句，不值得单独建立第二套 gen-l10n 生成工程。正式业务页面仍应
/// 使用根 ARB；这个手写类只服务于可删除占位组件，并在删除组件时一并移除。
class StarterStrings {
  const StarterStrings._({required this.message, required this.logout});

  /// 占位首页的说明文字。
  final String message;

  /// 退出登录按钮文字。
  final String logout;

  /// 使用 [context] 中当前 Locale 选择文案。
  ///
  /// 当前只区分中文与英文；其他语言回退英文。这里不保存 BuildContext，只在构建时
  /// 读取 languageCode，因此系统语言变化导致 Widget 重建后会得到新文案。
  static StarterStrings of(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == 'zh') {
      return const StarterStrings._(
        message: '企业项目底座已启动。请用第一个业务 Feature 替换此页面。',
        logout: '退出登录',
      );
    }
    return const StarterStrings._(
      message:
          'The enterprise starter is ready. '
          'Replace this page with your first business feature.',
      logout: 'Log out',
    );
  }
}
