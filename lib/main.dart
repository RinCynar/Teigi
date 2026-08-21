import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/app.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/core/utils/memory_trimmer.dart';
import 'package:teigi/core/utils/platform_info.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 限制图片缓存占用（默认 100MB / 1000 张，对媒体转换工具过大）。
  // 调小至 24MB / 100 张，降低桌面端与移动端 Dart 堆与渲染流水线的驻留开销。
  PaintingBinding.instance.imageCache.maximumSizeBytes = 24 << 20; // 24 MB
  PaintingBinding.instance.imageCache.maximumSize = 100;

  // 前台服务任务与 UI 之间的通信端口（Android 上后台转码时用于通知按钮回传）。
  if (isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
  }

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

  // 首帧渲染后对 Windows 桌面端执行物理工作集与初始堆整理
  if (isDesktop) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MemoryTrimmer.trimIdleMemory(delay: const Duration(milliseconds: 1000));
    });
  }
}

