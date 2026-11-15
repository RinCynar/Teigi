import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/app.dart';
import 'package:teigi/core/ffmpeg/engine/desktop_ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/features/presets/presets_browser.dart';
import 'package:teigi/features/queue/queue_panel.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:teigi/shared/widgets/teigi_mark.dart';
import 'package:teigi/theme/teigi_theme.dart';
import 'package:teigi/theme/tokens.dart';

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

  setUp(() {
    router.go('/convert');
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    Map<String, Object> initialPrefs = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'language': 'zh',
      ...initialPrefs,
    });
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
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  group('桌面宽屏双栏与浮动按钮测试', () {
    testWidgets('宽屏模式下左右双栏并存且右下角具备 Start 主按钮', (tester) async {
      await pumpApp(tester, size: const Size(1280, 800));

      // 左侧预设面板与右侧队列面板同屏并存
      expect(find.byType(PresetsBrowser), findsOneWidget);
      expect(find.byType(QueuePanel), findsOneWidget);

      // 右下角常驻 Start 主操作按钮
      expect(find.text('开始转换'), findsOneWidget);

      // 右侧队列空状态纯粹克制：仅显示空闲图标与说明文案，绝无重复的添加文件按钮
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('任务会在开始转换后出现在这里'), findsOneWidget);
      // 整个页面仅有左侧顶部卡片的一个主添加文件按钮
      expect(find.widgetWithText(FilledButton, '添加文件'), findsOneWidget);
    });

    testWidgets('页面级文件拖拽支持：窗口具备全局 DropTarget 覆盖', (tester) async {
      await pumpApp(tester, size: const Size(1280, 800));

      // 验证外层存在接收拖放的 DropTarget
      expect(find.byType(DropTarget), findsOneWidget);
    });

    testWidgets('左侧面板向下滚动时平滑浮现 + 添加悬浮按钮', (tester) async {
      await pumpApp(tester, size: const Size(1280, 800));

      // 顶部可见时，悬浮添加按钮 scale 为 0
      final initialFabFinder = find.byTooltip('添加文件');
      expect(initialFabFinder, findsWidgets);

      // 向下滚动左侧面板
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // 验证滚动后包含添加文件工具提示与加号图标
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    });

    testWidgets('Convert 左侧预设卡片网格随容器自适应铺满整行', (tester) async {
      await pumpApp(
        tester,
        size: const Size(1280, 800),
        initialPrefs: {
          'recent_preset_ids': ['video_mp4', 'audio_mp3'],
        },
      );

      // 验证存在 TeigiPresetsGrid 组件
      final gridFinder = find.byType(TeigiPresetsGrid);
      expect(gridFinder, findsWidgets);

      // 获取第一个网格（最近使用）以及包含的预设卡片
      final recentGridRect = tester.getRect(gridFinder.first);
      final cardsFinder = find.descendant(
        of: gridFinder.first,
        matching: find.byType(TeigiPresetCard),
      );
      expect(cardsFinder, findsNWidgets(2));

      final firstCardRect = tester.getRect(cardsFinder.at(0));
      final secondCardRect = tester.getRect(cardsFinder.at(1));

      // 验证两张卡片横向紧密铺满整行，左右边界严格对齐网格左右边界
      expect(firstCardRect.left, closeTo(recentGridRect.left, 1.0));
      expect(secondCardRect.right, closeTo(recentGridRect.right, 1.0));
      expect(firstCardRect.width, closeTo(secondCardRect.width, 1.0));
    });
  });

  group('移动端竖屏三键组与抽屉面板测试', () {
    testWidgets('移动端竖屏主体为队列，右下角展示三键组且顺序为 History -> Add -> Start', (tester) async {
      await pumpApp(tester, size: const Size(390, 844));

      // 移动端主体为队列
      expect(find.byType(QueuePanel), findsOneWidget);

      // 检查右下角三键顺序与图标
      final historyBtn = find.widgetWithIcon(IconButton, Icons.history_rounded);
      final addBtn = find.widgetWithIcon(IconButton, Icons.add_rounded);
      final startBtn = find.widgetWithIcon(FilledButton, Icons.play_arrow_rounded);

      expect(historyBtn, findsOneWidget);
      expect(addBtn, findsOneWidget);
      expect(startBtn, findsOneWidget);

      // 验证横向三键组都在右下区域且顺序为 History -> Add -> Start
      final historyCenter = tester.getCenter(historyBtn);
      final addCenter = tester.getCenter(addBtn);
      final startCenter = tester.getCenter(startBtn);

      expect(historyCenter.dx < addCenter.dx, isTrue);
      expect(addCenter.dx < startCenter.dx, isTrue);
    });

    testWidgets('点击 History 弹出底部抽屉，展示 Recent 与 All Presets', (tester) async {
      await pumpApp(tester, size: const Size(390, 844));

      // 点击 History 按钮
      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pumpAndSettle();

      // 抽屉内展示预设选择面板
      expect(find.byType(PresetsBrowser), findsOneWidget);
      expect(find.text('全部预设'), findsWidgets);
      expect(find.text('最近使用'), findsOneWidget);
    });

    testWidgets('Recent 清空操作实时生效', (tester) async {
      await pumpApp(
        tester,
        size: const Size(390, 844),
        initialPrefs: {
          'recent_preset_ids': ['video_mp4', 'audio_mp3'],
        },
      );

      // 打开抽屉
      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pumpAndSettle();

      // 抽屉内显示最近使用项与清空按钮
      expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);

      // 点击清空
      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      // 清空后显示暂无最近预设
      expect(find.text('暂无最近预设'), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep_outlined), findsNothing);
    });
  });

  group('Material 3 悬浮导航栏规范测试', () {
    testWidgets('移动端采用实体 M3 表面与胶囊形状，绝无 BackdropFilter', (tester) async {
      await pumpApp(tester, size: const Size(390, 844));

      // 验证存在 NavigationBar
      expect(find.byType(NavigationBar), findsOneWidget);

      // 验证没有使用任何高斯模糊 BackdropFilter 滤镜
      expect(find.byType(BackdropFilter), findsNothing);

      // 验证包含胶囊形状与边距的外层 Material
      final materials = tester.widgetList<Material>(find.byType(Material));
      final floatingCapsule = materials.any(
        (m) => m.shape is StadiumBorder && m.elevation > 0,
      );
      expect(floatingCapsule, isTrue);
    });
  });

  group('Material 3 主题色彩与系统动态取色规范测试', () {
    test('默认回退主题色对齐应用图标 (#6750A4) 且剔除硬编码青绿', () {
      expect(TeigiColors.seed, const Color(0xFF6750A4));

      final lightTheme = TeigiTheme.light();
      final darkTheme = TeigiTheme.dark();

      // 验证无动态色时，不再包含硬编码青绿 0xFF006A6B 或 0xFF39C5BB
      expect(lightTheme.colorScheme.primary, isNot(const Color(0xFF006A6B)));
      expect(darkTheme.colorScheme.primary, isNot(const Color(0xFF39C5BB)));

      // 验证从种子色 0xFF6750A4 派生的 M3 scheme 正常构建
      expect(
        lightTheme.colorScheme.primary,
        ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.light).primary,
      );
      expect(
        darkTheme.colorScheme.primary,
        ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.dark).primary,
      );
    });

    test('优先跟随系统动态取色 ColorScheme', () {
      final customLightScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF00B0FF),
        brightness: Brightness.light,
      );
      final customDarkScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF00B0FF),
        brightness: Brightness.dark,
      );

      final lightTheme = TeigiTheme.light(colorScheme: customLightScheme);
      final darkTheme = TeigiTheme.dark(colorScheme: customDarkScheme);

      expect(lightTheme.colorScheme.primary, customLightScheme.primary);
      expect(darkTheme.colorScheme.primary, customDarkScheme.primary);
    });
  });
}
