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
import 'package:teigi/shared/layout/desktop_navigation_rail.dart';
import 'package:teigi/shared/widgets/teigi_mark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    router.go('/convert');
  });

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
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
    await tester.pump();
    // 释放 ffmpeg 就绪横幅的自动隐藏定时器。
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('手机断点（<600dp）使用底部导航栏且无溢出', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DesktopNavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('平板断点（medium）使用侧边导航栏', (tester) async {
    await pumpApp(tester, const Size(800, 900));

    expect(find.byType(DesktopNavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏断点（expanded）使用侧边导航栏', (tester) async {
    await pumpApp(tester, const Size(1400, 900));

    expect(find.byType(DesktopNavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动端竖屏（360x780）各页面自适应渲染且无溢出', (tester) async {
    await pumpApp(tester, const Size(360, 780));

    // 转换主页在手机竖屏上正常渲染无溢出
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 切换至队列页
    await tester.tap(find.text('队列'));
    await tester.pumpAndSettle();
    expect(find.text('队列'), findsWidgets);
    expect(tester.takeException(), isNull);

    // 切换至预设页
    await tester.tap(find.text('预设'));
    await tester.pumpAndSettle();
    expect(find.text('预设'), findsWidgets);
    expect(tester.takeException(), isNull);

    // 切换至设置页
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('主题模式'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('侧边栏支持展开与折叠切换', (tester) async {
    await pumpApp(tester, const Size(1200, 800));

    expect(find.byKey(const Key('sidebar-toggle-btn')), findsOneWidget);
    expect(find.text('Teigi'), findsWidgets);
    expect(find.byType(TeigiMark), findsNothing);

    // 点击折叠按钮
    await tester.tap(find.byKey(const Key('sidebar-toggle-btn')));
    await tester.pumpAndSettle();

    final rail = tester.widget<DesktopNavigationRail>(find.byType(DesktopNavigationRail));
    expect(rail.extended, isFalse);

    // 再次点击展开按钮
    await tester.tap(find.byKey(const Key('sidebar-toggle-btn')));
    await tester.pumpAndSettle();

    final railExpanded = tester.widget<DesktopNavigationRail>(find.byType(DesktopNavigationRail));
    expect(railExpanded.extended, isTrue);
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
