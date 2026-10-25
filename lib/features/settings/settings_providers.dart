import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置状态
class SettingsState {
  final ThemeMode themeMode;
  final int autoLockMinutes;
  final bool clipboardAutoClear;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.autoLockMinutes = 5,
    this.clipboardAutoClear = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    int? autoLockMinutes,
    bool? clipboardAutoClear,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      clipboardAutoClear: clipboardAutoClear ?? this.clipboardAutoClear,
    );
  }
}

/// 设置状态管理（SharedPreferences 持久化）
class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _keyThemeMode = 'settings.themeMode';
  static const _keyAutoLock = 'settings.autoLockMinutes';
  static const _keyClipboardAutoClear = 'settings.clipboardAutoClear';

  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_keyThemeMode);
    final autoLock = prefs.getInt(_keyAutoLock);
    final clipboardAutoClear = prefs.getBool(_keyClipboardAutoClear);

    state = state.copyWith(
      themeMode: themeModeIndex != null
          ? ThemeMode.values[themeModeIndex]
          : null,
      autoLockMinutes: autoLock,
      clipboardAutoClear: clipboardAutoClear,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    state = state.copyWith(autoLockMinutes: minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoLock, minutes);
  }

  Future<void> setClipboardAutoClear(bool enabled) async {
    state = state.copyWith(clipboardAutoClear: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyClipboardAutoClear, enabled);
  }
}

/// 设置提供者
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
