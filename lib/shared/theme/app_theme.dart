// lib/shared/theme/app_theme.dart
//
// 作用：集中管理 App 的明暗主题配置，避免 MaterialApp 中直接写 ThemeData。
//
// 设计要点：
// 1. 构造函数私有化，只通过静态方法 light() 和 dark() 获取主题
// 2. ThemeData 在 ThemeProvider 中缓存，避免每次 build 都重新创建
// 3. 主题配置集中管理，方便统一调整颜色、字体、间距等
// 4. 组件样式（如 AppBarTheme、CardTheme）也可以在这里统一配置
//
// 扩展方式：
// - 新增自定义颜色：添加 static const Color xxx = Color(0xFF...)
// - 新增组件主题：在 ThemeData 中添加 cardTheme、inputDecorationTheme 等
// - 支持更多主题变体：添加 static ThemeData highContrast() 等方法

import 'package:flutter/material.dart';

/// App 主题管理类。
///
/// 所有主题相关的配置集中在这里，而不是散落在 MaterialApp 和各个页面中。
/// ThemeProvider 在启动时调用 light() 和 dark() 创建 ThemeData 并缓存。
class AppTheme {
  const AppTheme._();

  /// 浅色主题（Material 3）。
  ///
  /// 配置项说明：
  /// - colorScheme: fromSeed(indigo) → 从靛蓝色种子生成完整配色方案（Material 3 推荐方式）
  /// - scaffoldBackgroundColor: #F7F8FA → 浅灰背景，比纯白色更柔和
  /// - appBarTheme: 无阴影、标题居中
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: colorScheme,
      // 页面背景色：浅灰比纯白更柔和，适合长时间阅读
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      // AppBar 样式：无阴影（扁平化设计）、标题居中
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
    );
  }

  /// 深色主题（Material 3）。
  ///
  /// 配置项说明：
  /// - colorScheme: fromSeed(indigo) → 深色模式下自动生成暗色调配色
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
    );
  }
}
