import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/app.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/core/utils/platform_info.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 前台服务任务与 UI 之间的通信端口（Android 上后台转码时用于通知按钮回传）。
  FlutterForegroundTask.initCommunicationPort();

  // 桌面窗口初始化。window_manager 仅实现于桌面平台，移动端/Web 上调用会
  // 抛 MissingPluginException，因此必须跳过。
  if (isDesktop) {
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
  }

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

