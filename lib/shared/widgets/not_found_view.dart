// lib/shared/widgets/not_found_view.dart
//
// 作用：404 页面，当用户访问的路由无法匹配时展示。
//
// 显示时机：
// - GoRouter 无法匹配任何路由时（由 AppRouter 的 errorBuilder 触发）
// - 用户手动输入了不存在的路径
//
// 交互逻辑：
// - 展示"页面不存在"提示
// - 提供"返回首页"按钮，点击后跳转到主页面

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/route_paths.dart';

/// 404 页面：路由匹配失败时展示。
///
/// 不直接返回空白页，而是提供友好的提示和返回首页的入口，
/// 减少用户的迷路感。
class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 404 提示文案
            const Text(AppStrings.pageNotFound),
            const SizedBox(height: 16),
            // 返回首页按钮
            // RoutePaths.home 直接指向真实存在的商品 Tab 路由。
            ElevatedButton(
              onPressed: () => context.go(RoutePaths.home),
              child: const Text(AppStrings.backHome),
            ),
          ],
        ),
      ),
    );
  }
}
