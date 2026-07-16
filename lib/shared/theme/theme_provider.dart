// lib/shared/theme/theme_provider.dart
//
// 作用：全局主题管理器，管理明暗主题切换，并把用户选择持久化到本地。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_storage.dart';
import 'app_theme.dart';

// ==================== 状态类 ====================

/// 全局主题状态（不可变）。
class ThemeState {
  const ThemeState({
    this.themeMode = ThemeMode.light,
    required this.lightTheme,
    required this.darkTheme,
  });

  /// 当前主题模式
  final ThemeMode themeMode;

  /// 浅色主题缓存
  final ThemeData lightTheme;

  /// 深色主题缓存
  final ThemeData darkTheme;

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
  static const String _themeKey = 'theme_mode';

  @override
  ThemeState build() {
    // LocalStorage 已由 BootstrapGate 尝试初始化，而且读取 API 是同步的。
    // 直接用持久化结果构造首个 State，可以避免 App 先显示浅色再闪到深色；
    // 存储降级时 getString 返回 null，主题安全回退到 light。
    final savedMode = LocalStorage.getString(_themeKey);
    return ThemeState(
      themeMode: savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
      lightTheme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
    );
  }

  /// 切换明暗主题并保存到本地。
  Future<void> toggleTheme() async {
    final newMode = state.themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    state = state.copyWith(themeMode: newMode);

    await LocalStorage.setString(
      _themeKey,
      newMode == ThemeMode.dark ? 'dark' : 'light',
    );
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
