// lib/navigation/main_shell.dart
//
// 作用：登录后的主框架页，通过 StatefulNavigationShell + BottomNavigationBar 管理三个 Tab。
//
// 架构说明：
// - 使用 GoRouter 的 StatefulNavigationShell 替代手动 IndexedStack + MainViewModel
// - GoRouter 管理每个 Tab 的子路由和页面状态，切换 Tab 不会销毁子页面
// - navigationShell.goBranch(index) 处理 Tab 切换，支持深层路由
//
// 路由结构（由 demo_route_bundle.dart 的 StatefulShellRoute 定义）：
// /main
//   ├── /main/home   → 商品目录与购物车
//   │     └── /main/home/cart → 购物车详情
//   ├── /main/orders → 订单列表与订单生命周期
//   └── /main/mine   → 我的与设置

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/demo_strings.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  /// GoRouter 提供的导航外壳，管理子路由栈和当前激活分支
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // navigationShell 本身是当前分支的 Navigator/Widget 树。
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        // Tab 索引属于路由状态，不再创建只保存 int 的 MainViewModel。
        onTap: (index) => navigationShell.goBranch(
          index,
          // 点击当前 Tab 时回到该分支的初始路由，避免深层嵌套
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            label: DemoStrings.home,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: DemoStrings.orders,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: DemoStrings.mine,
          ),
        ],
      ),
    );
  }
}
