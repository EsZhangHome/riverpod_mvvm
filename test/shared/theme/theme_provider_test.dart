// ThemeNotifier 只依赖可注入 PreferencesStore；测试不初始化平台插件或共享全局状态。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/providers/service_providers.dart';
import 'package:riverpod_mvvm/core/storage/preferences_store.dart';
import 'package:riverpod_mvvm/shared/theme/theme_provider.dart';

final class _MemoryPreferencesStore implements PreferencesStore {
  _MemoryPreferencesStore([Map<String, Object> initial = const {}])
    : values = {...initial};

  final Map<String, Object> values;

  @override
  bool getBool(String key, {bool defaultValue = false}) {
    return values[key] as bool? ?? defaultValue;
  }

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

void main() {
  test('build synchronously restores saved dark theme', () async {
    final preferences = _MemoryPreferencesStore({'theme_mode': 'dark'});
    final container = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    final state = container.read(themeProvider);

    expect(state.themeMode, ThemeMode.dark);
  });

  test('toggle updates state and persists the new mode', () async {
    final preferences = _MemoryPreferencesStore({'theme_mode': 'light'});
    final container = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    await container.read(themeProvider.notifier).toggleTheme();

    expect(container.read(themeProvider).themeMode, ThemeMode.dark);
    expect(preferences.getString('theme_mode'), 'dark');
  });
}
