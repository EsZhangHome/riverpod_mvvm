// lib/shared/ui/loading_view.dart
//
// 作用：通用加载视图，所有页面 loading 状态都可以复用。
//
// 显示时机：
// - 列表页首次加载时（replace 模式）
// - 表单提交时（overlay 模式，由 StateView 在 loading 上叠加遮罩）
//
// 当前只展示一个居中的 CircularProgressIndicator，后续可以扩展为：
// - 骨架屏（SkeletonView）
// - 带动画的自定义加载组件
// - 支持加载文案（如"正在加载..."）

import 'package:flutter/material.dart';

/// 通用加载视图。
///
/// 居中展示 CircularProgressIndicator，适用于所有页面的 loading 状态。
/// 通过 StateView 统一调用，业务页面不需要直接使用这个组件。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    // 简单居中展示加载动画
    // 后续可以替换为更丰富的加载效果（如骨架屏、品牌动画等）
    return const Center(child: CircularProgressIndicator());
  }
}
