import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/media_file.dart';
import 'package:teigi/features/format_config/format_selector.dart';
import 'package:teigi/features/format_config/options_editor.dart';
import 'package:teigi/features/queue/queue_panel.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/conversion_engine.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/widgets/ffmpeg_status_banner.dart';

/// 主界面：自适应布局（窄屏顶部工具栏+队列 / 中等左侧队列+右侧面板 / 宽屏三栏）。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    // 监听 ffmpeg 状态与转换引擎，确保启动即检测/调度。
    ref.watch(ffmpegStatusProvider);
    ref.watch(conversionEngineProvider);

    // 导航高亮跟随当前路由：设置页返回后自动回到「队列」。
    final isOnSettings = GoRouterState.of(context).uri.path == '/settings';
    final selectedIndex = isOnSettings ? 1 : 0;

    final isMedium = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      drawer: isMedium ? null : _buildDrawer(context, selectedIndex),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragOver = true),
        onDragExited: (_) => setState(() => _dragOver = false),
        onDragDone: (details) => _handleDroppedFiles(details.files),
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isWide = width >= 1400;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 导航栏：窄屏用 Drawer 按钮 + 顶部栏，中宽屏用 NavigationRail。
                    if (isMedium)
                      _buildNavigationRail(context, selectedIndex)
                    else
                      const SizedBox.shrink(),
                    Expanded(
                      child: Column(
                        children: [
                          _buildTopBar(context, isMedium: isMedium),
                          const FfmpegStatusBanner(),
                          Expanded(
                            child: isWide
                                ? const Row(
                                    children: [
                                      Expanded(flex: 3, child: QueuePanel()),
                                      VerticalDivider(width: 1),
                                      Expanded(flex: 2, child: _RightPanel()),
                                    ],
                                  )
                                : const QueuePanel(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // 拖拽悬停遮罩提示。
            if (_dragOver)
              Positioned.fill(
                child: Material(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.85),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.file_download_outlined, size: 64),
                        const SizedBox(height: 16),
                        Text(l10n.addFiles,
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- 导入 ----------------

  /// 处理拖拽释放的文件。
  Future<void> _handleDroppedFiles(List<DropItem> items) async {
    setState(() => _dragOver = false);
    final files = [
      for (final item in items)
        if (item.path.isNotEmpty) MediaFile(path: item.path),
    ];
    if (files.isEmpty) return;
    if (!mounted) return;

    final fmt = await _askTargetFormat(context);
    _addFilesWithFormat(files, fmt: fmt);
  }

  /// 通过文件选择器导入文件（支持任意扩展名）。
  Future<void> _importFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final files = [
      for (final f in result.files)
        if (f.path != null) MediaFile(path: f.path!),
    ];
    if (files.isEmpty) return;
    if (!mounted) return;

    final fmt = await _askTargetFormat(context);
    _addFilesWithFormat(files, fmt: fmt);
  }

  /// 导入整个文件夹（包含任意扩展名文件）。
  Future<void> _importDirectory() async {
    final l10n = ref.read(l10nProvider);
    final path = await FilePicker.getDirectoryPath(dialogTitle: l10n.chooseFolder);
    if (path == null) return;

    final dir = Directory(path);
    if (!await dir.exists()) return;

    final files = await dir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .toList();
    if (!mounted) return;

    final fmt = await _askTargetFormat(context);
    _addFilesWithFormat([for (final f in files) MediaFile(path: f.path)], fmt: fmt);
  }

  /// 将文件加入队列并应用目标格式/选项。
  void _addFilesWithFormat(
    List<MediaFile> files, {
    required (String?, ConversionOptions?) fmt,
  }) {
    final notifier = ref.read(queueProvider.notifier);
    final (format, options) = fmt;
    notifier.addFiles(files, targetFormat: format);
    if (options != null) {
      // 为本次导入的任务应用选项。
      final paths = files.map((f) => f.path).toSet();
      for (final t in ref.read(queueProvider)) {
        if (paths.contains(t.source.path)) {
          notifier.setOptions(t.id, options);
        }
      }
    }
  }

  /// 导入后询问目标格式（支持自定义与配置选项，可跳过）。
  Future<(String?, ConversionOptions?)> _askTargetFormat(
    BuildContext context,
  ) async {
    final l10n = ref.read(l10nProvider);
    String? selected;
    ConversionOptions? options;

    final result = await showDialog<(String?, ConversionOptions?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.chooseTargetFormat),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormatSelector(
                value: selected,
                onChanged: (v) => setState(() => selected = v),
                onQuickOptionsApplied: (o) => setState(() => options = o),
              ),
              if (selected != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showModalBottomSheet<ConversionOptions>(
                      context: context,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (_) => _OptionPickerSheet(
                        format: selected!,
                        initial: options ?? const ConversionOptions(),
                      ),
                    );
                    if (picked != null) setState(() => options = picked);
                  },
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(l10n.configOptions),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop((null, null)),
              child: Text(l10n.skip),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop((selected, options)),
              child: Text(l10n.ok),
            ),
          ],
        ),
      ),
    );
    // 点遮罩关闭等情况下 result 可能为 null。
    return result ?? (null, null);
  }


  // ---------------- 导航 ----------------

  /// 中宽屏左侧导航栏。
  Widget _buildNavigationRail(BuildContext context, int selectedIndex) {
    final l10n = ref.watch(l10nProvider);
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == 1) {
          context.push('/settings');
        } else {
          context.go('/');
        }
      },
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: FlutterLogo(size: 28),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.playlist_play),
          label: Text(l10n.navQueue),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: Text(l10n.navSettings),
        ),
      ],
    );
  }

  /// 窄屏抽屉导航。
  Widget _buildDrawer(BuildContext context, int selectedIndex) {
    final l10n = ref.watch(l10nProvider);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const FlutterLogo(size: 32),
                const SizedBox(height: 8),
                Text(l10n.appTitle, style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: Text(l10n.navQueue),
            selected: selectedIndex == 0,
            onTap: () {
              Navigator.of(context).pop();
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.navSettings),
            selected: selectedIndex == 1,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/settings');
            },
          ),
        ],
      ),
    );
  }

  /// 顶部工具栏（有导航栏时不再显示设置按钮）。
  Widget _buildTopBar(BuildContext context, {required bool isMedium}) {
    final l10n = ref.watch(l10nProvider);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 仅当侧边栏未显示时（窄屏）展示菜单按钮。
            if (!isMedium) ...[
              IconButton(
                icon: const Icon(Icons.menu),
                tooltip: l10n.menu,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.folder_open_outlined),
              tooltip: l10n.importFolder,
              onPressed: _importDirectory,
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _importFiles,
              icon: const Icon(Icons.add),
              label: Text(l10n.addFiles),
            ),
          ],
        ),
      ),
    );
  }
}

/// 右侧配置/日志面板（阶段 2 占位）。
class _RightPanel extends ConsumerWidget {
  const _RightPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final queueCount = ref.watch(queueProvider).length;
    return Center(
      child: Text(
        '${l10n.configOptions}\n\n队列任务数：$queueCount',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// 选项选择弹层（返回选定的 ConversionOptions）。
class _OptionPickerSheet extends ConsumerWidget {
  final String format;
  final ConversionOptions initial;

  const _OptionPickerSheet({required this.format, required this.initial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    ConversionOptions? picked;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.configOptions,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(picked),
                  child: Text(l10n.ok),
                ),
              ],
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  OptionsForm(
                    targetFormat: format,
                    initial: initial,
                    onChanged: (o) => picked = o,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

