import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/app.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面窗口初始化。
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(760, 520),
    center: true,
    title: 'Teigi',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 加载持久化设置。
  final prefs = await SharedPreferences.getInstance();
  final settings = await AppSettings.load(prefs);

  runApp(
    ProviderScope(
      overrides: [
        // 注入 SharedPreferences 实例供 settings/quickFormats 等 Provider 使用。
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier(settings, prefs),
        ),
      ],
      child: const TeigiApp(),
    ),
  );
}

