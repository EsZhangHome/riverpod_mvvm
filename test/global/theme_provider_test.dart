// ThemeNotifier 持久化测试：LocalStorage 在容器创建前初始化，因此 build() 可以
// 同步恢复主题，首帧不会先使用默认浅色再闪烁。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/storage/local_storage.dart';
import 'package:riverpod_mvvm/global/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('build synchronously restores saved dark theme', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    await LocalStorage.init();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(themeProvider);

    expect(state.themeMode, ThemeMode.dark);
  });

  test('toggle updates state and persists the new mode', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    await LocalStorage.init();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeProvider.notifier).toggleTheme();

    expect(container.read(themeProvider).themeMode, ThemeMode.dark);
    expect(LocalStorage.getString('theme_mode'), 'dark');
  });
}
