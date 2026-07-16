// lib/app/navigation/not_found_page.dart
//
// 作用：404 页面，当用户访问的路由无法匹配时展示。
//
// 显示时机：
// - GoRouter 无法匹配任何路由时（由 AppRouter 的 errorBuilder 触发）
// - 用户手动输入了不存在的路径
//
// 交互逻辑：
// - 展示"页面不存在"提示
// - 提供"返回首页"按钮，由登录守卫决定当前项目的真实首页

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/localization/app_strings.dart';
import '../../shared/navigation/route_paths.dart';

/// 404 页面：路由匹配失败时展示。
///
/// 不直接返回空白页，而是提供友好的提示和返回首页的入口，
/// 减少用户的迷路感。
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.fallbackPath = RoutePaths.login});

  final String fallbackPath;

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
            // 先进入登录路由：未登录用户停留在登录页；已登录用户会被
            // AuthRouteGuard 重定向到当前路由包的 authenticatedHome。
            // 因此 404 页面不需要依赖任何项目的具体业务首页。
            ElevatedButton(
              onPressed: () => context.go(fallbackPath),
              child: const Text(AppStrings.backHome),
            ),
          ],
        ),
      ),
    );
  }
}
