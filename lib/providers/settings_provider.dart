import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/core/models/app_settings.dart';

/// SharedPreferences 实例 Provider（在 main() 中通过 override 注入）。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider 需要在 main() 中 override');
});

/// 应用全局设置 Provider（读写 + 持久化）。
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  // 常规路径下初始状态由 main() 通过 override 注入。
  return SettingsNotifier(
    const AppSettings(),
    prefs,
  );
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(super.initialState, this._prefs);

  final SharedPreferences _prefs;

  /// 应用新设置并立即持久化。
  Future<void> update(AppSettings newSettings) async {
    state = newSettings;
    await newSettings.save(_prefs);
  }

  Future<void> setFfmpegPath(String path) =>
      update(state.copyWith(ffmpegPath: path));

  Future<void> setOutputDirectory(String path) =>
      update(state.copyWith(outputDirectory: path));

  Future<void> setConcurrency(int n) => update(state.copyWith(concurrency: n));

  Future<void> setHardwareAccel(bool value) =>
      update(state.copyWith(hardwareAccel: value));

  Future<void> setThemeMode(String mode) =>
      update(state.copyWith(themeMode: mode));

  Future<void> setSeedColor(Color color) =>
      update(state.copyWith(seedColor: color));

  Future<void> setUseDynamicColor(bool value) =>
      update(state.copyWith(useDynamicColor: value));

  Future<void> setOpenOutputAfterDone(bool value) =>
      update(state.copyWith(openOutputAfterDone: value));

  Future<void> setLanguage(String code) =>
      update(state.copyWith(language: code));
}
