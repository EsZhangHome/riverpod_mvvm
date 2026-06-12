// lib/global/theme_provider.dart
//
// 作用：全局主题管理器，管理明暗主题切换，并把用户选择持久化到本地。
//
// 迁移说明（Provider → Riverpod）：
// - 旧的 ThemeProvider extends ChangeNotifier → 新的 ThemeNotifier extends Notifier<ThemeState>
// - notifyListeners() → state = newState

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/local_storage.dart';
import '../core/theme/app_theme.dart';

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
    // 创建 ThemeData 缓存（启动时只创建一次）
    final state = ThemeState(
      lightTheme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
    );
    // 异步加载本地保存的主题模式（Future.microtask：build 期间 state 未就绪）
    Future.microtask(_loadSavedTheme);
    return state;
  }

  Future<void> _loadSavedTheme() async {
    final savedMode = LocalStorage.getString(_themeKey);
    state = state.copyWith(
      themeMode: savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
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
