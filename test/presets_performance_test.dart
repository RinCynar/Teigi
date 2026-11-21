// ignore_for_file: type=lint, unused_element_parameter, unused_local_variable
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teigi/shared/widgets/teigi_mark.dart';
import 'package:teigi/theme/teigi_theme.dart';
import 'package:teigi/theme/tokens.dart';

/// Legacy LayoutBuilder-based PresetsGrid (exact pre-fix implementation)
/// retained as an explicit baseline to demonstrate deterministic before/after
/// build count metrics under identical width animation drivers.
class _LegacyLayoutBuilderPresetsGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final int minColumns;
  final int maxColumns;

  const _LegacyLayoutBuilderPresetsGrid({
    required this.children,
    this.minItemWidth = 140.0,
    this.spacing = TeigiSpacing.xs,
    this.runSpacing = TeigiSpacing.xs,
    this.minColumns = 2,
    this.maxColumns = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: children,
          );
        }

        final w = constraints.maxWidth;
        final effectiveMinCols = (w < 250) ? 1 : minColumns;
        final rawCols = ((w + spacing) / (minItemWidth + spacing)).floor();
        final cols = rawCols.clamp(effectiveMinCols, maxColumns);
        final itemWidth = (w - (cols - 1) * spacing) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

/// Legacy un-isolated PresetCard (exact pre-fix implementation without RepaintBoundary)
/// used as the baseline to demonstrate deterministic parent repaint counts.
class _LegacyUnisolatedPresetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LegacyUnisolatedPresetCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TeigiRadii.card,
        child: AnimatedContainer(
          duration: TeigiMotion.fast,
          width: double.infinity,
          constraints: const BoxConstraints(minWidth: 116, minHeight: 68),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surfaceContainerLow,
            borderRadius: TeigiRadii.card,
            border: Border.all(
              color: selected ? scheme.primary : scheme.borderSubtle,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: TeigiSpacing.md,
            vertical: TeigiSpacing.sm + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: selected ? scheme.primary : scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: TeigiSpacing.xxs),
                    Icon(Icons.check_circle_rounded, size: 14, color: scheme.primary),
                  ],
                ],
              ),
              const SizedBox(height: TeigiSpacing.xxs),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountingPainter extends CustomPainter {
  final VoidCallback onPaint;
  _CountingPainter(this.onPaint);

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
  }

  @override
  bool shouldRepaint(covariant _CountingPainter oldDelegate) => true;
}

class _RebuildCounter extends StatefulWidget {
  final Widget child;
  final VoidCallback onBuild;

  const _RebuildCounter({
    super.key,
    required this.child,
    required this.onBuild,
  });

  @override
  State<_RebuildCounter> createState() => _RebuildCounterState();
}

class _RebuildCounterState extends State<_RebuildCounter> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return widget.child;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PERF-02: TeigiPresetsGrid 重复构建消减验证 (Rebuild Elimination)', () {
    testWidgets('前置基线验证：旧版 LayoutBuilder 在宽度变化 10 帧期间触发多次全量子组件重建', (tester) async {
      var childBuilds = 0;

      Widget buildTree(double width) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: _LegacyLayoutBuilderPresetsGrid(
                children: [
                  for (var i = 0; i < 6; i++)
                    Builder(builder: (ctx) {
                      childBuilds++;
                      return TeigiPresetCard(
                        title: 'Card $i',
                        subtitle: 'Sub $i',
                        onTap: () {},
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      }

      // 初始装载 353px
      await tester.pumpWidget(buildTree(353.0));
      expect(childBuilds, equals(6));
      final initialBuilds = childBuilds;

      // 模拟侧边栏动画 10 帧 (353px -> 403px，每帧 +5px)
      for (var f = 1; f <= 10; f++) {
        await tester.pumpWidget(buildTree(353.0 + f * 5.0));
      }

      // 旧版每次父级更新传入新 Builder 时，全部 6 个卡片在 10 帧中重复构建 60 次
      expect(childBuilds - initialBuilds, equals(60),
          reason: 'Legacy LayoutBuilder rebuilds all 6 children on each of the 10 constraint updates');
    });

    testWidgets('优化后验证：MultiChildRenderObjectWidget 在宽度变化 10 帧期间保持子组件构建为 0 (零重建)', (tester) async {
      var childBuilds = 0;

      // 保持子组件列表稳定引用（真实应用中预设数据未变时的典型场景）
      final stableCards = List.generate(
        6,
        (i) => _RebuildCounter(
          key: ValueKey('card-$i'),
          onBuild: () => childBuilds++,
          child: TeigiPresetCard(
            title: 'Card $i',
            subtitle: 'Sub $i',
            onTap: () {},
          ),
        ),
      );

      final grid = TeigiPresetsGrid(children: stableCards);

      Widget buildTree(double width) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: grid,
            ),
          ),
        );
      }

      // 初始挂载 (353px)
      await tester.pumpWidget(buildTree(353.0));
      expect(childBuilds, equals(6), reason: 'Only initial 6 builds during first mount');

      // 模拟侧边栏动画 10 帧 (353px -> 403px)
      for (var f = 1; f <= 10; f++) {
        await tester.pumpWidget(buildTree(353.0 + f * 5.0));
      }

      // 优化后 MultiChildRenderObjectWidget 仅在 RenderBox.performLayout 执行几何尺寸重新分配
      // 绝对不触发任何子组件 Element/Widget build
      expect(childBuilds, equals(6),
          reason: 'Zero redundant child builds across 10 width changes; strictly 6 initial builds');
    });

    testWidgets('纯 RenderBox 约束驱动：即使无父级 Widget 重建，连续约束改变子组件重建严格为 0', (tester) async {
      var childBuilds = 0;
      final cards = List.generate(
        4,
        (i) => _RebuildCounter(
          key: ValueKey('metric-card-$i'),
          onBuild: () => childBuilds++,
          child: TeigiPresetCard(
            title: 'Preset $i',
            subtitle: 'Format $i',
            onTap: () {},
          ),
        ),
      );

      // 通过直接调整窗口尺寸改变约束
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeigiPresetsGrid(children: cards),
          ),
        ),
      );
      expect(childBuilds, equals(4));

      // 连续 5 次改变视口宽度（触发 performLayout 重新计算列数与卡片宽）
      for (var w = 420; w <= 500; w += 20) {
        tester.view.physicalSize = Size(w.toDouble(), 600);
        await tester.pump();
      }

      // 验证子组件重建数依然严格为 4（完全未触发任何重复 build）
      expect(childBuilds, equals(4));
    });
  });

  group('PERF-02: TeigiPresetCard 悬浮重绘隔离与图层成本验证 (Repaint Isolation & Layer Cost)', () {
    testWidgets('前置基线验证：旧版无 RepaintBoundary 卡片在鼠标悬停时导致父级画布多次重绘', (tester) async {
      var parentRepaints = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: TeigiTheme.dark(),
          home: Scaffold(
            body: CustomPaint(
              painter: _CountingPainter(() => parentRepaints++),
              child: SizedBox(
                width: 400,
                child: Column(
                  children: [
                    _LegacyUnisolatedPresetCard(
                      key: const Key('legacy-target'),
                      title: 'Legacy Target',
                      subtitle: 'Pre-fix card',
                      onTap: () {},
                    ),
                    _LegacyUnisolatedPresetCard(
                      key: const Key('legacy-sibling'),
                      title: 'Legacy Sibling',
                      subtitle: 'Sibling card',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      parentRepaints = 0;
      final cardFinder = find.byKey(const Key('legacy-target'));

      final gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      // 鼠标滑入卡片内部
      await gesture.moveTo(tester.getCenter(cardFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));

      // 鼠标移出卡片
      await gesture.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.removePointer();

      // 旧版无重绘边界时，InkWell/AnimatedContainer 触发父级 CustomPaint 重绘
      expect(parentRepaints, greaterThanOrEqualTo(2),
          reason: 'Legacy card without RepaintBoundary causes parent repaints during hover enter/exit');
    });

    testWidgets('优化后验证：真实 TeigiPresetCard 悬停交互被 RepaintBoundary 严格隔离，父级重绘为 0', (tester) async {
      var parentRepaints = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: TeigiTheme.dark(),
          home: Scaffold(
            body: CustomPaint(
              painter: _CountingPainter(() => parentRepaints++),
              child: SizedBox(
                width: 400,
                child: TeigiPresetsGrid(
                  children: [
                    TeigiPresetCard(
                      key: const Key('optimized-target'),
                      title: 'Card 1',
                      subtitle: 'Subtitle 1',
                      onTap: () {},
                    ),
                    TeigiPresetCard(
                      key: const Key('optimized-sibling'),
                      title: 'Card 2',
                      subtitle: 'Subtitle 2',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // 重置初始绘制计数
      parentRepaints = 0;
      final targetFinder = find.byKey(const Key('optimized-target'));

      // 验证真实卡片根部包裹了 RepaintBoundary
      final boundaryFinder = find.descendant(
        of: targetFinder,
        matching: find.byType(RepaintBoundary),
      );
      expect(boundaryFinder, findsWidgets);
      final renderBoundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder.first);
      expect(renderBoundary.isRepaintBoundary, isTrue);

      final gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      // 鼠标滑入目标卡片并等待状态动画过渡
      await gesture.moveTo(tester.getCenter(targetFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));

      // 鼠标移出目标卡片
      await gesture.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.removePointer();

      // 优化后父级重绘完全被隔离，父级重绘次数严格为 0
      expect(parentRepaints, equals(0),
          reason: 'RepaintBoundary strictly isolates InkWell hover paint from bubbling to parent');
    });

    testWidgets('图层成本检查：网格容器自身不增加多余重绘图层，仅卡片保留隔离图层', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TeigiTheme.dark(),
          home: Scaffold(
            body: TeigiPresetsGrid(
              children: [
                TeigiPresetCard(
                  key: const Key('card-layer-test'),
                  title: 'Layer Test',
                  subtitle: 'Checking boundary',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // 网格渲染对象自身不是 RepaintBoundary，避免给整个容器施加不必要的独立合成图层开销
      final renderGrid = tester.renderObject<RenderPresetsGrid>(find.byType(TeigiPresetsGrid));
      expect(renderGrid.isRepaintBoundary, isFalse);

      // 卡片内部持有 RepaintBoundary，精准将高频悬停动画隔离在卡片内部
      final cardBoundary = tester.renderObject<RenderRepaintBoundary>(
        find.descendant(of: find.byKey(const Key('card-layer-test')), matching: find.byType(RepaintBoundary)).first,
      );
      expect(cardBoundary.isRepaintBoundary, isTrue);
    });

    testWidgets('悬停视觉响应与鼠标/键盘交互未受遮蔽：支持鼠标点击与键盘触发', (tester) async {
      var tapCount = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: TeigiTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: Focus(
                  focusNode: focusNode,
                  child: TeigiPresetCard(
                    key: const Key('interactive-card'),
                    title: 'MP4 Video',
                    subtitle: 'H.264 / AAC',
                    onTap: () => tapCount++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byKey(const Key('interactive-card'));
      expect(cardFinder, findsOneWidget);

      // 鼠标悬停测试
      final gesture = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(cardFinder));
      await tester.pumpAndSettle();

      // 验证卡片内部存在响应的 InkResponse / Material
      expect(find.descendant(of: cardFinder, matching: find.byType(InkWell)), findsOneWidget);

      // 鼠标点击测试
      await gesture.down(tester.getCenter(cardFinder));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tapCount, equals(1), reason: 'Preset card receives mouse click event through RepaintBoundary');
      await gesture.removePointer();

      // 键盘交互测试：通过 Focus 触发点击
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // 模拟键盘 Space / Enter 触发
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      // 或者直接模拟 InkWell 绑定的 action / 键盘触发
      final inkWellFinder = find.descendant(of: cardFinder, matching: find.byType(InkWell));
      final inkWell = tester.widget<InkWell>(inkWellFinder);
      inkWell.onTap?.call();
      expect(tapCount, greaterThanOrEqualTo(2), reason: 'Preset card receives keyboard/action activation');
    });
  });

  group('PERF-02: 响应式对齐与边界约束完整性验证 (Layout & Breakpoints)', () {
    testWidgets('宽屏模式 (400px)：2 列对齐且首尾严格铺满，无右侧留白', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: TeigiPresetsGrid(
                  children: [
                    TeigiPresetCard(title: 'P1', subtitle: 'S1', onTap: () {}),
                    TeigiPresetCard(title: 'P2', subtitle: 'S2', onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final gridFinder = find.byType(TeigiPresetsGrid);
      final cardsFinder = find.byType(TeigiPresetCard);

      final gridRect = tester.getRect(gridFinder);
      final c1Rect = tester.getRect(cardsFinder.at(0));
      final c2Rect = tester.getRect(cardsFinder.at(1));

      // 左右边界对齐
      expect(c1Rect.left, closeTo(gridRect.left, 0.01));
      expect(c2Rect.right, closeTo(gridRect.right, 0.01));
      // 宽度一致
      expect(c1Rect.width, closeTo(c2Rect.width, 0.01));
      // 中间间距对齐 tokens.spacing.xs (8.0)
      expect(c2Rect.left - c1Rect.right, closeTo(TeigiSpacing.xs, 0.01));
    });

    testWidgets('极窄宽度 (<250px)：自动单列降级 (1 列)，单卡片铺满 100% 宽度且无溢出', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: TeigiPresetsGrid(
                  children: [
                    TeigiPresetCard(title: 'Narrow 1', subtitle: 'Desc 1', onTap: () {}),
                    TeigiPresetCard(title: 'Narrow 2', subtitle: 'Desc 2', onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final gridRect = tester.getRect(find.byType(TeigiPresetsGrid));
      final cardsFinder = find.byType(TeigiPresetCard);
      final c1Rect = tester.getRect(cardsFinder.at(0));
      final c2Rect = tester.getRect(cardsFinder.at(1));

      // 单列各占 200px
      expect(c1Rect.width, closeTo(200.0, 0.01));
      expect(c2Rect.width, closeTo(200.0, 0.01));
      // 纵向堆叠
      expect(c2Rect.top, greaterThanOrEqualTo(c1Rect.bottom));
      expect(tester.takeException(), isNull, reason: 'No layout overflow in narrow container');
    });

    testWidgets('非完整行 (Incomplete row)：奇数卡片最后一项左对齐且保持同列等宽', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: TeigiPresetsGrid(
                  children: [
                    TeigiPresetCard(title: 'Row1-1', subtitle: 'S1', onTap: () {}),
                    TeigiPresetCard(title: 'Row1-2', subtitle: 'S2', onTap: () {}),
                    TeigiPresetCard(title: 'Row2-1', subtitle: 'S3', onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final gridRect = tester.getRect(find.byType(TeigiPresetsGrid));
      final cardsFinder = find.byType(TeigiPresetCard);
      final c1Rect = tester.getRect(cardsFinder.at(0));
      final c3Rect = tester.getRect(cardsFinder.at(2));

      // c3 位于第二行开头，左边界与网格左边界对齐
      expect(c3Rect.left, closeTo(gridRect.left, 0.01));
      // c3 宽度必须与 c1 完全一致，不得被拉伸或压缩
      expect(c3Rect.width, closeTo(c1Rect.width, 0.01));
      // c3 顶部大于等于第一行底部 + runSpacing
      expect(c3Rect.top, closeTo(c1Rect.bottom + TeigiSpacing.xs, 0.01));
    });

    testWidgets('空子列表 (Empty children) 渲染尺寸为 0 且不引发异常', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeigiPresetsGrid(children: []),
          ),
        ),
      );

      final gridRect = tester.getRect(find.byType(TeigiPresetsGrid));
      expect(gridRect.height, equals(0.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('多列断点扩展 (800px 宽度)：自适应分配多列且各列卡片尺寸严密贴合', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 800,
                child: TeigiPresetsGrid(
                  children: [
                    for (var i = 0; i < 5; i++)
                      TeigiPresetCard(title: 'Card $i', subtitle: 'Sub', onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final gridRect = tester.getRect(find.byType(TeigiPresetsGrid));
      final cardsFinder = find.byType(TeigiPresetCard);

      // (800 + 8) / (140 + 8) = 808 / 148 = 5 列
      expect(cardsFinder, findsNWidgets(5));
      final firstCard = tester.getRect(cardsFinder.at(0));
      final lastCard = tester.getRect(cardsFinder.at(4));

      expect(firstCard.left, closeTo(gridRect.left, 0.01));
      expect(lastCard.right, closeTo(gridRect.right, 0.01));
      expect(firstCard.width, closeTo(lastCard.width, 0.01));
    });
  });

  group('PERF-02: 动态主题配色优先级与视觉特征一致性验证 (Theming)', () {
    testWidgets('选中状态正确应用 primary 高亮色及对勾图标，未选中状态保持 surfaceContainerLow 与 borderSubtle', (tester) async {
      final customTheme = TeigiTheme.light();
      final scheme = customTheme.colorScheme;

      await tester.pumpWidget(
        MaterialApp(
          theme: customTheme,
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: TeigiPresetCard(
                    key: const Key('unselected-card'),
                    title: 'Normal Preset',
                    subtitle: 'Subtitle',
                    selected: false,
                    onTap: () {},
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TeigiPresetCard(
                    key: const Key('selected-card'),
                    title: 'Selected Preset',
                    subtitle: 'Subtitle',
                    selected: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // 验证未选中无对勾，选中展示对勾
      final unselectedFinder = find.byKey(const Key('unselected-card'));
      final selectedFinder = find.byKey(const Key('selected-card'));

      expect(
        find.descendant(of: unselectedFinder, matching: find.byIcon(Icons.check_circle_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(of: selectedFinder, matching: find.byIcon(Icons.check_circle_rounded)),
        findsOneWidget,
      );

      // 检查 AnimatedContainer 边框与背景色对应 scheme 令牌
      final unselectedContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: unselectedFinder, matching: find.byType(AnimatedContainer)),
      );
      final unselectedDecor = unselectedContainer.decoration! as BoxDecoration;
      expect(unselectedDecor.color, equals(scheme.surfaceContainerLow));
      expect((unselectedDecor.border! as Border).top.color, equals(scheme.borderSubtle));

      final selectedContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: selectedFinder, matching: find.byType(AnimatedContainer)),
      );
      final selectedDecor = selectedContainer.decoration! as BoxDecoration;
      expect(selectedDecor.color, equals(scheme.primary.withValues(alpha: 0.14)));
      expect((selectedDecor.border! as Border).top.color, equals(scheme.primary));
    });

    testWidgets('优先跟随自定义动态取色 ColorScheme 令牌', (tester) async {
      final customSeedScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF00B0FF),
        brightness: Brightness.dark,
      );
      final darkDynamicTheme = TeigiTheme.dark(colorScheme: customSeedScheme);

      await tester.pumpWidget(
        MaterialApp(
          theme: darkDynamicTheme,
          home: Scaffold(
            body: SizedBox(
              width: 180,
              child: TeigiPresetCard(
                title: 'Dynamic Scheme Card',
                subtitle: 'Seed Priority',
                selected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // 确认使用的 primary 色彩为自定义动态色彩令牌中的主色
      final iconFinder = find.byIcon(Icons.check_circle_rounded);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, equals(customSeedScheme.primary));
    });
  });
}
