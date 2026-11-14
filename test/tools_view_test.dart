import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/app.dart';
import 'package:teigi/core/ffmpeg/engine/desktop_ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/features/tools/ncm_decrypt_view.dart';
import 'package:teigi/features/tools/tools_page.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/settings_provider.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('导航至 Tools 页面并进入 NCM 解密视图', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'language': 'zh'});
    final prefs = await SharedPreferences.getInstance();
    final settings = await AppSettings.load(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(settings, prefs),
          ),
          ffmpegStatusProvider.overrideWith(
            () => _FakeFfmpegNotifier(),
          ),
          ffmpegEngineProvider.overrideWithValue(DesktopFfmpegEngine()),
        ],
        child: const TeigiApp(),
      ),
    );
    await tester.pump();

    // 1. 跳转至 /tools
    router.go('/tools');
    await tester.pumpAndSettle();

    expect(find.byType(ToolsPage), findsOneWidget);
    expect(find.text('工具箱'), findsWidgets);
    expect(find.text('NCM 解密'), findsOneWidget);

    // 2. 点击 NCM 解密卡片
    await tester.tap(find.text('NCM 解密'));
    await tester.pumpAndSettle();

    expect(find.byType(NcmDecryptView), findsOneWidget);
    expect(find.text('添加 NCM 文件'), findsOneWidget);

    // 3. 点击返回按钮返回 Tools
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ToolsPage), findsOneWidget);
  });
}
