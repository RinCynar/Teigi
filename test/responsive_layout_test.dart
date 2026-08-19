import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:teigi/app.dart';
import 'package:teigi/core/ffmpeg/engine/desktop_ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await AppSettings.load(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(settings, prefs),
          ),
          ffmpegStatusProvider.overrideWith(() => _FakeFfmpegNotifier()),
          ffmpegEngineProvider.overrideWithValue(DesktopFfmpegEngine()),
        ],
        child: const TeigiApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    // 释放 ffmpeg 就绪横幅的自动隐藏定时器。
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('手机断点（<600dp）使用底部导航栏且无溢出', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('平板断点（medium）使用侧边导航栏', (tester) async {
    await pumpApp(tester, const Size(800, 900));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏断点（expanded）使用侧边导航栏', (tester) async {
    await pumpApp(tester, const Size(1400, 900));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// 固定返回「可用」状态的假 ffmpeg 检测器。
class _FakeFfmpegNotifier extends FfmpegStatusNotifier {
  @override
  Future<FfmpegEngineStatus> build() async {
    return const FfmpegEngineStatus(
      isReady: true,
      version: 'test-0.0',
      resolvedExecutablePath: 'ffmpeg',
    );
  }
}
