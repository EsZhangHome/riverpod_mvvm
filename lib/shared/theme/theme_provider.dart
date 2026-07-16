// lib/shared/theme/theme_provider.dart
//
// 作用：全局主题管理器，管理明暗主题切换，并把用户选择持久化到本地。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import 'app_theme.dart';

// ==================== 状态类 ====================

/// 全局主题状态（不可变）。
class ThemeState {
  /// 创建不可变主题状态。
  ///
  /// - [themeMode]：MaterialApp 当前采用 light/dark/system 中哪种模式；底座默认 light；
  /// - [lightTheme]/[darkTheme]：预先构建并缓存的两套 ThemeData，避免 Widget 每次
  ///   重建都重复生成完整颜色方案。
  const ThemeState({
    this.themeMode = ThemeMode.light,
    required this.lightTheme,
    required this.darkTheme,
  });

  /// 当前主题模式，直接传给 MaterialApp.router.themeMode。
  final ThemeMode themeMode;

  /// 浅色主题缓存，直接传给 MaterialApp.router.theme。
  final ThemeData lightTheme;

  /// 深色主题缓存，直接传给 MaterialApp.router.darkTheme。
  final ThemeData darkTheme;

  /// 只替换主题模式并复用已经构建的 ThemeData。
  ///
  /// [themeMode] 为 null 表示沿用旧值；ThemeData 不开放替换是为了把配色变更集中在
  /// AppTheme。如果业务要支持动态品牌主题，应扩展明确字段，而不是页面直接修改。
  ThemeState copyWith({ThemeMode? themeMode}) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      lightTheme: lightTheme,
      darkTheme: darkTheme,
    );
  }
}

// ==================== Notifier ====================

/// 全局主题 Notifier。
class ThemeNotifier extends Notifier<ThemeState> {
  /// SharedPreferences 中保存主题选择的 key。
  ///
  /// 修改 key 会让已安装用户丢失旧选择；若确实需要改名，应提供迁移而不是直接替换。
  static const String _themeKey = 'theme_mode';

  @override
  ThemeState build() {
    // 默认 PreferencesStore 已由 BootstrapGate 尝试初始化，而且读取 API 是同步的。
    // 直接用持久化结果构造首个 State，可以避免 App 先显示浅色再闪到深色；
    // 测试或项目壳可以 override Provider，不需要改 ThemeNotifier。
    final savedMode = ref.watch(preferencesStoreProvider).getString(_themeKey);
    return ThemeState(
      themeMode: savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
      lightTheme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
    );
  }

  /// 在 light 与 dark 之间切换，并把选择保存到本地。
  ///
  /// 内存 state 先更新，界面立即响应；随后通过可注入 PreferencesStore 持久化。
  /// 默认降级实现不会抛未初始化错误。当前底座不切到 ThemeMode.system，如需增加
  /// 明确设置方法，而不是让 toggle 的三态循环难以预测。
  Future<void> toggleTheme() async {
    final newMode = state.themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    state = state.copyWith(themeMode: newMode);

    await ref
        .read(preferencesStoreProvider)
        .setString(_themeKey, newMode == ThemeMode.dark ? 'dark' : 'light');
  }
}

// ==================== Provider ====================

/// 全局主题 Provider。
///
/// 使用方式：
/// ```dart
/// final themeState = ref.watch(themeProvider);
/// final themeMode = themeState.themeMode;
/// ref.read(themeProvider.notifier).toggleTheme();
/// ```
final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);
