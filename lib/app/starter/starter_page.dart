// lib/app/starter/starter_page.dart
//
// 底座默认登录后的占位页面。它不是一个示例业务 feature，而是验证“启动、登录、
// 路由、主题、本地化”已经连通的最小落点。真实项目创建自己的 AppRouteBundle 后，
// 把 authenticatedHome 指向真实首页即可；无需修改或继承 StarterPage。

import 'package:flutter/material.dart';

import '../../core/config/env_config.dart';
import '../../l10n/app_localizations.dart';

/// 底座登录成功后的最小落点。
///
/// 这个页面只证明启动、认证、路由、主题和本地化已经连通，不包含任何 Demo 业务。
/// 新项目接入真实首页后可以保留它做诊断页。若决定删除，需先把 main.dart、
/// MyApp/BootstrapGate 的默认路由包等 `AppRouteBundle.starter()` 用法全部替换，
/// 再删除 AppRouter 的路由注册、RoutePaths.starter、页面和相关测试；仅删本文件
/// 或两个路由引用会导致编译失败。
class StarterPage extends StatelessWidget {
  const StarterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(EnvConfig.appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context).starterMessage,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
