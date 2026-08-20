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
import 'package:teigi/shared/layout/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('应用根组件可构建', (WidgetTester tester) async {
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
        ],
        child: const TeigiApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Teigi'), findsWidgets);

    // 推进时间以释放 ffmpeg 就绪横幅的自动隐藏定时器。
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('导航到设置页不再触发 UnimplementedError', (WidgetTester tester) async {
    // 放大测试窗口以显示 NavigationRail。
    tester.view.physicalSize = const Size(1400, 900);
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
          ffmpegStatusProvider.overrideWith(() => _FakeFfmpegNotifier()),
          // 这些测试验证桌面布局，固定注入桌面引擎（含 FFmpeg 路径设置项）。
          ffmpegEngineProvider.overrideWithValue(DesktopFfmpegEngine()),
        ],
        child: const TeigiApp(),
      ),
    );
    await tester.pump();

    // 点击导航栏「设置」标签。
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    // 设置页正常渲染（AppBar 标题），无 UnimplementedError。
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);
    expect(find.byKey(const Key('settings-about-entry')), findsNothing);
    await tester.tap(find.byKey(const Key('settings-category-4')));
    await tester.pumpAndSettle();
    final bodyRect = tester.getRect(find.byKey(const Key('settings-body')));
    final presetsRect = tester.getRect(
      find.byKey(const Key('settings-content-quick-formats')),
    );
    expect(presetsRect.top, greaterThanOrEqualTo(bodyRect.top));
    expect(presetsRect.top, lessThan(bodyRect.bottom));

    // 滚动到「快捷格式」分区，验证设置页内容可以正常滚动。
    // 同时验证 quickFormatsProvider 依赖的 SharedPreferences 已正确注入。
    await tester.dragUntilVisible(
      find.text('快捷格式'),
      find.byKey(const Key('settings-body')),
      const Offset(0, -200),
    );
    expect(find.text('快捷格式'), findsOneWidget);

    // 释放横幅定时器。
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('About 路由保持 Settings 高亮并可返回', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
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
          ffmpegStatusProvider.overrideWith(() => _FakeFfmpegNotifier()),
          ffmpegEngineProvider.overrideWithValue(DesktopFfmpegEngine()),
        ],
        child: const TeigiApp(),
      ),
    );
    await tester.pump();

    router.go('/settings/about');
    await tester.pumpAndSettle();

    expect(find.text('关于 Teigi'), findsOneWidget);
    expect(AppShell.indexFor('/settings/about'), 3);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);
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
