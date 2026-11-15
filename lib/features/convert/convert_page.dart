import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/core/models/media_file.dart';
import 'package:teigi/features/convert/media_import.dart';
import 'package:teigi/features/presets/presets_browser.dart';
import 'package:teigi/features/queue/queue_panel.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/conversion_engine.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/recent_presets_provider.dart';
import 'package:teigi/providers/selection_provider.dart';
import 'package:teigi/shared/widgets/ffmpeg_status_banner.dart';
import 'package:teigi/theme/tokens.dart';

/// 转换工作台页面：桌面端左右分栏同屏呈现，移动端队列主体配合悬浮操作三键组。
class ConvertPage extends ConsumerStatefulWidget {
  const ConvertPage({super.key});

  static const _import = MediaImport();

  @override
  ConsumerState<ConvertPage> createState() => _ConvertPageState();

  static void addFiles(WidgetRef ref, List<MediaFile> files) {
    if (files.isEmpty) return;
    final pending = ref.read(pendingPresetProvider);
    ref.read(queueProvider.notifier).addFiles(files, preset: pending);
    if (pending != null) {
      ref.read(pendingPresetProvider.notifier).state = null;
    }
  }

  /// 启动转换：存在未指定目标格式的任务时先弹窗确认。
  ///
  /// 供转换页按钮与全局 Ctrl+Enter 快捷键共用，保证两条路径行为一致。
  static Future<bool> startConversion(BuildContext context, WidgetRef ref) async {
    final l10n = ref.read(l10nProvider);
    final missing = [
      for (final t in ref.read(queueProvider))
        if (t.status == TaskStatus.queued &&
            (t.targetFormat == null || t.targetFormat!.isEmpty))
          t,
    ].length;
    if (missing == 0) {
      ref.read(conversionEngineProvider).start();
      return true;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.startConversion),
        content: Text(l10n.missingOutput(missing)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'review'),
            child: Text(l10n.reviewMissing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'ready'),
            child: Text(l10n.startReady),
          ),
        ],
      ),
    );
    if (choice == 'ready') {
      ref.read(conversionEngineProvider).start();
      return true;
    }
    return false;
  }
}

class _ConvertPageState extends ConsumerState<ConvertPage> {
  final ScrollController _leftScrollController = ScrollController();
  bool _showLeftAddFab = false;

  @override
  void initState() {
    super.initState();
    _leftScrollController.addListener(_onLeftScroll);
  }

  @override
  void dispose() {
    _leftScrollController.removeListener(_onLeftScroll);
    _leftScrollController.dispose();
    super.dispose();
  }

  void _onLeftScroll() {
    if (!_leftScrollController.hasClients) return;
    // 当左栏向下滚动使顶部的 Add Files 卡片移出视口时，浮现快捷添加按钮
    final show = _leftScrollController.offset > 180;
    if (show != _showLeftAddFab) {
      setState(() => _showLeftAddFab = show);
    }
  }

  Future<void> _addFromPicker() async {
    final files = await ConvertPage._import.pickFiles();
    if (!mounted) return;
    ConvertPage.addFiles(ref, files);
  }

  void _onSelectPreset(FormatPreset preset) {
    final selected = ref.read(selectionProvider);
    final queuedTasks = ref
        .read(queueProvider)
        .where((t) => t.status == TaskStatus.queued)
        .map((t) => t.id)
        .toSet();

    if (selected.isNotEmpty) {
      ref.read(queueProvider.notifier).applyPresetTo(selected, preset);
    } else if (queuedTasks.isNotEmpty) {
      ref.read(queueProvider.notifier).applyPreset(preset);
    }

    ref.read(pendingPresetProvider.notifier).state = preset;
    ref.read(recentPresetsProvider.notifier).record(preset.id);

    final l10n = ref.read(l10nProvider);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.presetWillApply(preset.name)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMobilePresetsSheet() {
    final l10n = ref.read(l10nProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.allPresets,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: TeigiSpacing.lg,
                  vertical: TeigiSpacing.md,
                ),
                children: [
                  PresetsBrowser(
                    scrollable: false,
                    onSelectPreset: (preset) {
                      _onSelectPreset(preset);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(ffmpegStatusProvider);
    final width = MediaQuery.sizeOf(context).width;
    final size = TeigiBreakpoints.sizeOf(width);
    final isCompact = size == TeigiWindowSize.compact;
    final selected = ref.watch(selectionProvider);
    final tasks = ref.watch(queueProvider);
    final queuedTasks = tasks.where((t) => t.status == TaskStatus.queued).toList();

    return PopScope(
      canPop: selected.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ref.read(selectionProvider.notifier).clear();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
            ref.read(selectionProvider.notifier).selectAll(queuedTasks.map((t) => t.id));
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            ref.read(selectionProvider.notifier).clear();
          },
          const SingleActivator(LogicalKeyboardKey.delete): () {
            ref.read(queueProvider.notifier).removeTasks(ref.read(selectionProvider));
            ref.read(selectionProvider.notifier).clear();
          },
        },
        child: Focus(
          autofocus: true,
          child: RepaintBoundary(
            child: isCompact
                ? _MobileConvertLayout(
                    onAddFiles: _addFromPicker,
                    onOpenHistory: _showMobilePresetsSheet,
                    onStart: () => ConvertPage.startConversion(context, ref),
                  )
                : _DesktopConvertLayout(
                    leftScrollController: _leftScrollController,
                    showLeftAddFab: _showLeftAddFab,
                    onAddFiles: _addFromPicker,
                    onSelectPreset: _onSelectPreset,
                    onStart: () => ConvertPage.startConversion(context, ref),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 桌面端宽屏双栏布局：左右比例约为 10:23 (约 1:2.3)
class _DesktopConvertLayout extends StatelessWidget {
  final ScrollController leftScrollController;
  final bool showLeftAddFab;
  final VoidCallback onAddFiles;
  final ValueChanged<FormatPreset> onSelectPreset;
  final VoidCallback onStart;

  const _DesktopConvertLayout({
    required this.leftScrollController,
    required this.showLeftAddFab,
    required this.onAddFiles,
    required this.onSelectPreset,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 左侧面板：内部独立滚动，排布 Add Files、Recent 与 All Presets
        Expanded(
          flex: 1,
          child: _DesktopLeftPanel(
            scrollController: leftScrollController,
            showAddFab: showLeftAddFab,
            onAddFiles: onAddFiles,
            onSelectPreset: onSelectPreset,
          ),
        ),

        // 分割线
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: scheme.borderSubtle,
        ),

        // 2. 右侧面板：常驻展示 Queue（任务队列）并在右下角常驻 Start 主按钮
        Expanded(
          flex: 2,
          child: _DesktopRightPanel(
            onAddFiles: onAddFiles,
            onStart: onStart,
          ),
        ),
      ],
    );
  }
}

class _DesktopLeftPanel extends ConsumerWidget {
  final ScrollController scrollController;
  final bool showAddFab;
  final VoidCallback onAddFiles;
  final ValueChanged<FormatPreset> onSelectPreset;

  const _DesktopLeftPanel({
    required this.scrollController,
    required this.showAddFab,
    required this.onAddFiles,
    required this.onSelectPreset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return Stack(
      children: [
        ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            TeigiSpacing.md,
            TeigiSpacing.md,
            TeigiSpacing.sm,
            TeigiSpacing.xxl + 32,
          ),
          children: [
            const FfmpegStatusBanner(),
            _HeroWorkbench(
              isMobile: false,
              l10n: l10n,
              onAddFiles: onAddFiles,
            ),
            const SizedBox(height: TeigiSpacing.xl),
            PresetsBrowser(
              scrollable: false,
              onSelectPreset: onSelectPreset,
            ),
          ],
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: AnimatedScale(
            scale: showAddFab ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: showAddFab ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: FloatingActionButton.small(
                heroTag: 'left_add_files_fab',
                tooltip: l10n.addFiles,
                onPressed: onAddFiles,
                child: const Icon(Icons.add_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopRightPanel extends ConsumerWidget {
  final VoidCallback onAddFiles;
  final VoidCallback onStart;

  const _DesktopRightPanel({
    required this.onAddFiles,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final tasks = ref.watch(queueProvider);
    final running = ref.watch(conversionRunningProvider);
    final hasQueuedTasks = tasks.any((t) => t.status == TaskStatus.queued);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TeigiSpacing.md,
            TeigiSpacing.lg,
            TeigiSpacing.lg,
            TeigiSpacing.lg,
          ),
          child: QueuePanel(
            embedded: true,
            onAddFiles: onAddFiles,
            bottomPadding: 88,
          ),
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            heroTag: 'desktop_start_conversion_fab',
            elevation: 3,
            onPressed: running
                ? null
                : (hasQueuedTasks ? onStart : null),
            icon: Icon(
              running ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(
              running ? l10n.converting : l10n.startConversion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

/// 移动端竖屏布局：主体区域直接展示 Queue，并在右下角放置横向排列的三按钮动作组
class _MobileConvertLayout extends ConsumerWidget {
  final VoidCallback onAddFiles;
  final VoidCallback onOpenHistory;
  final VoidCallback onStart;

  const _MobileConvertLayout({
    required this.onAddFiles,
    required this.onOpenHistory,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final tasks = ref.watch(queueProvider);
    final running = ref.watch(conversionRunningProvider);
    final hasQueuedTasks = tasks.any((t) => t.status == TaskStatus.queued);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TeigiSpacing.md,
            TeigiSpacing.md,
            TeigiSpacing.md,
            0,
          ),
          child: QueuePanel(
            embedded: true,
            onAddFiles: onAddFiles,
            bottomPadding: 88,
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. History (Recent) - Secondary
              IconButton.filledTonal(
                tooltip: l10n.recentPresets,
                icon: const Icon(Icons.history_rounded),
                onPressed: onOpenHistory,
              ),
              const SizedBox(width: 8),
              // 2. Add Files - Secondary
              IconButton.filledTonal(
                tooltip: l10n.addFiles,
                icon: const Icon(Icons.add_rounded),
                onPressed: onAddFiles,
              ),
              const SizedBox(width: 8),
              // 3. Start Conversion - Primary
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: const StadiumBorder(),
                  elevation: 2,
                ),
                onPressed: running
                    ? null
                    : (hasQueuedTasks ? onStart : null),
                icon: Icon(
                  running
                      ? Icons.hourglass_top_rounded
                      : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(
                  running ? l10n.converting : l10n.startConversion,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroWorkbench extends StatefulWidget {
  final bool isMobile;
  final L10n l10n;
  final VoidCallback onAddFiles;

  const _HeroWorkbench({
    required this.isMobile,
    required this.l10n,
    required this.onAddFiles,
  });

  @override
  State<_HeroWorkbench> createState() => _HeroWorkbenchState();
}

class _HeroWorkbenchState extends State<_HeroWorkbench> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg = _isHovered ? scheme.surfaceContainer : scheme.surfaceContainerLow;
    final borderColor = _isHovered
        ? scheme.primary.withValues(alpha: 0.35)
        : scheme.borderSubtle;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onAddFiles,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 14 : 16,
              vertical: widget.isMobile ? 20 : 24,
            ),
            child: _HeroWorkbenchContent(
              isMobile: widget.isMobile,
              l10n: widget.l10n,
              onAddFiles: widget.onAddFiles,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroWorkbenchContent extends StatelessWidget {
  final bool isMobile;
  final L10n l10n;
  final VoidCallback onAddFiles;

  const _HeroWorkbenchContent({
    required this.isMobile,
    required this.l10n,
    required this.onAddFiles,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isMobile ? 44 : 52,
          height: isMobile ? 44 : 52,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.file_upload_outlined,
            size: isMobile ? 22 : 28,
            color: scheme.primary,
          ),
        ),
        SizedBox(height: isMobile ? 10 : 12),
        Text(
          l10n.convertSubtitle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 15 : 17,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          isMobile ? l10n.selectToStart : l10n.dropToStart,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
        ),
        SizedBox(height: isMobile ? 12 : 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: isMobile ? 8 : 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onAddFiles,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            l10n.addFiles,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.borderSubtle, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isMobile ? l10n.mobileImportHint : l10n.dropHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
