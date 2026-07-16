// lib/shared/ui/empty_view.dart
//
// 作用：通用空数据视图，提示用户当前没有数据。
//
// 显示时机：
// - 列表接口请求成功但返回的数据为空（如长度为 0）
// - 搜索无结果
// - 筛选条件无匹配数据
//
// 与 ErrorView 的区别：
// - EmptyView：请求成功，但数据为空（如空列表）
// - ErrorView：请求失败（网络异常、业务错误等）

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// 通用空数据视图。
///
/// 展示空数据图标和提示文案。
/// 通过 StateView 统一调用，业务页面不需要直接使用这个组件。
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message = AppStrings.noData});

  /// 提示文案，默认 "暂无数据"
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        // 最小尺寸，内容居中
        mainAxisSize: MainAxisSize.min,
        children: [
          // 空数据图标：使用弱提示图标，不打断用户
          // hintColor 让图标颜色更柔和，区别于错误状态
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(height: 12),
          // 提示文案
          Text(message),
        ],
      ),
    );
  }
}
