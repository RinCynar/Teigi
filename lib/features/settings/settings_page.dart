import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/utils/platform_info.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/quick_formats_provider.dart';
import 'package:teigi/providers/settings_provider.dart';

/// 设置页：ffmpeg 路径、输出目录、并发、主题、快捷格式等。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _section = 0;
  final ScrollController _bodyController = ScrollController();
  final List<GlobalKey> _sectionKeys = List.generate(5, (_) => GlobalKey());

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  void _selectSection(
    int index,
    List<int> contentIndexForSection,
    int aboutSectionIndex,
  ) {
    if (index == aboutSectionIndex) {
      context.go('/settings/about');
      return;
    }

    setState(() => _section = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _sectionKeys[contentIndexForSection[index]].currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final settings = ref.watch(settingsProvider);
    final ffmpegEngine = ref.watch(ffmpegEngineProvider);
    final ffmpegStatus = ref.watch(ffmpegStatusProvider);
    final quickFormats = ref.watch(quickFormatsProvider);

    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final contentIndexForSection = <int>[3, 1, 2];
    final sections = <String>[
      l10n.general,
      l10n.conversionSettings,
      l10n.appearance,
    ];
    if (ffmpegEngine.capabilities.supportsCustomExecutablePath) {
      sections.add('FFmpeg');
      contentIndexForSection.add(0);
    }
    sections.add(l10n.navPresets);
    contentIndexForSection.add(4);
    sections.add(l10n.about);
    final aboutSectionIndex = sections.length - 1;

    final body = SingleChildScrollView(
      key: const Key('settings-body'),
      controller: _bodyController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ffmpegEngine.capabilities.supportsCustomExecutablePath)
            _SectionCard(
              key: _sectionKeys[0],
              sectionKey: 'ffmpeg',
              title: 'ffmpeg',
              icon: Icons.movie_filter_outlined,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.ffmpegPathTitle),
                  subtitle: Text(
                    _ffmpegPathSubtitle(settings, ffmpegStatus, l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        tooltip: l10n.browse,
                        onPressed: () => _pickFfmpegPath(ref),
                      ),
                      if (settings.ffmpegPath.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: l10n.resetPathDetect,
                          onPressed: () => _clearFfmpegPath(ref),
                        ),
                    ],
                  ),
                ),
                _StatusRow(ffmpegStatus: ffmpegStatus),
              ],
            ),
          _SectionCard(
            key: _sectionKeys[1],
            sectionKey: 'conversion',
            title: l10n.conversionSettings,
            icon: Icons.tune,
            children: [
              if (isDesktop)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.outputDirectory),
                  subtitle: Text(
                    settings.outputDirectory.isEmpty
                        ? l10n.sameAsSource
                        : settings.outputDirectory,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.folder_open),
                    tooltip: l10n.browse,
                    onPressed: () => _pickOutputDirectory(ref),
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.concurrency),
                subtitle: Text(l10n.concurrencyDesc(settings.concurrency)),
                trailing: DropdownButton<int>(
                  value: settings.concurrency,
                  items: [
                    for (var i = 1; i <= 8; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(settingsProvider.notifier).setConcurrency(v);
                    }
                  },
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.hardwareAccel),
                subtitle: Text(l10n.hardwareAccelHint),
                value: settings.hardwareAccel,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setHardwareAccel(v),
              ),
            ],
          ),
          _SectionCard(
            key: _sectionKeys[2],
            sectionKey: 'appearance',
            title: l10n.appearance,
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.languageLabel),
                trailing: DropdownButton<String>(
                  value: settings.language,
                  items: const [
                    DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                    DropdownMenuItem(value: 'ja', child: Text('日本語')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(settingsProvider.notifier).setLanguage(v);
                    }
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.themeMode),
                trailing: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'system',
                      label: Text(l10n.followSystem),
                    ),
                    ButtonSegment(value: 'light', label: Text(l10n.lightMode)),
                    ButtonSegment(value: 'dark', label: Text(l10n.darkMode)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) =>
                      ref.read(settingsProvider.notifier).setThemeMode(s.first),
                ),
              ),
              _SeedColorTile(l10n: l10n, settings: settings),
            ],
          ),
          _SectionCard(
            key: _sectionKeys[3],
            sectionKey: 'behaviors',
            title: l10n.behaviors,
            icon: Icons.playlist_add_check_circle_outlined,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.openOutputAfterDone),
                value: settings.openOutputAfterDone,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setOpenOutputAfterDone(v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.conflictPolicy),
                trailing: DropdownButton<OverwritePolicy>(
                  value: settings.overwritePolicy,
                  items: [
                    DropdownMenuItem(
                      value: OverwritePolicy.keepBoth,
                      child: Text(l10n.keepBoth),
                    ),
                    DropdownMenuItem(
                      value: OverwritePolicy.overwrite,
                      child: Text(l10n.overwrite),
                    ),
                    DropdownMenuItem(
                      value: OverwritePolicy.skip,
                      child: Text(l10n.skip),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .update(settings.copyWith(overwritePolicy: v));
                    }
                  },
                ),
              ),
            ],
          ),
          _SectionCard(
            key: _sectionKeys[4],
            sectionKey: 'quick-formats',
            title: l10n.quickFormats,
            icon: Icons.star_outline,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.quickFormatsHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (quickFormats.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.noFormatYet),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in quickFormats)
                      InputChip(
                        label: Text(f.extension.toUpperCase()),
                        onDeleted: () => ref
                            .read(quickFormatsProvider.notifier)
                            .remove(f.extension),
                      ),
                  ],
                ),
            ],
          ),
          if (!wide) ...[
            const SizedBox(height: 8),
            ListTile(
              key: const Key('settings-about-entry'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.about),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings/about'),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Teigi v0.0.2-alpha',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSettings),
        automaticallyImplyLeading: false,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 200,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        children: [
                          for (var i = 0; i < sections.length; i++)
                            ListTile(
                              key: ValueKey('settings-category-$i'),
                              title: Text(sections[i]),
                              selected: _section == i,
                              onTap: () => _selectSection(
                                i,
                                contentIndexForSection,
                                aboutSectionIndex,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
        ),
      ),
    );
  }

  Future<void> _pickFfmpegPath(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'ffmpeg',
      type: FileType.custom,
      allowedExtensions: ['exe', 'bin', ''],
    );
    if (result != null && result.files.single.path != null) {
      await ref
          .read(settingsProvider.notifier)
          .setFfmpegPath(result.files.single.path!);
      await ref.read(ffmpegStatusProvider.notifier).redetect();
    }
  }

  Future<void> _clearFfmpegPath(WidgetRef ref) async {
    await ref.read(settingsProvider.notifier).setFfmpegPath('');
    await ref.read(ffmpegStatusProvider.notifier).redetect();
  }

  String _ffmpegPathSubtitle(
    AppSettings settings,
    AsyncValue<FfmpegEngineStatus> status,
    L10n l10n,
  ) {
    final detected = status.valueOrNull;
    return switch (detected?.source) {
      FfmpegEngineSource.custom =>
        detected?.resolvedExecutablePath ?? settings.ffmpegPath,
      FfmpegEngineSource.bundled => l10n.useBundledFfmpeg,
      FfmpegEngineSource.systemPath => l10n.usePathFfmpeg,
      null =>
        settings.ffmpegPath.isEmpty ? l10n.usePathFfmpeg : settings.ffmpegPath,
    };
  }

  Future<void> _pickOutputDirectory(WidgetRef ref) async {
    final l10n = ref.read(l10nProvider);
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.outputDirectory,
    );
    if (path != null) {
      await ref.read(settingsProvider.notifier).setOutputDirectory(path);
    }
  }
}

/// 种子颜色设置行：预设色板 + 十六进制输入。
class _SeedColorTile extends ConsumerStatefulWidget {
  final L10n l10n;
  final AppSettings settings;

  const _SeedColorTile({required this.l10n, required this.settings});

  @override
  ConsumerState<_SeedColorTile> createState() => _SeedColorTileState();
}

class _SeedColorTileState extends ConsumerState<_SeedColorTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _toHex(widget.settings.seedColor),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const List<Color> _presetColors = [
    Color(0xFF6750A4), // 紫
    Color(0xFF00696D), // 青
    Color(0xFF006D40), // 绿
    Color(0xFFB3261E), // 红
    Color(0xFF8F4C00), // 橙
    Color(0xFF3D5BA9), // 蓝
    Color(0xFF000000), // 黑
    Color(0xFF9E9E9E), // 灰
  ];

  static String _toHex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final settings = widget.settings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.seedColor, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _presetColors)
                InkWell(
                  onTap: () =>
                      ref.read(settingsProvider.notifier).setSeedColor(c),
                  child: CircleAvatar(
                    backgroundColor: c,
                    radius: 16,
                    child: c == settings.seedColor
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '#6750A4',
                    labelText: l10n.seedColor,
                    prefixText: '#',
                  ),
                  onSubmitted: (v) {
                    final hex = v.replaceAll('#', '').trim();
                    final color = int.tryParse(hex, radix: 16);
                    if (color != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setSeedColor(Color(0xFF000000 | color));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.seedColorHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ffmpeg 检测结果状态行。
class _StatusRow extends ConsumerWidget {
  final AsyncValue<FfmpegEngineStatus> ffmpegStatus;

  const _StatusRow({required this.ffmpegStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;
    return ffmpegStatus.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => _statusChip(
        scheme.errorContainer,
        Icons.error,
        l10n.detectFailed('$e'),
      ),
      data: (s) {
        if (s.isReady && s.isFallback) {
          final fallbackText = switch (s.source) {
            FfmpegEngineSource.bundled => l10n.customPathInvalidUsingBundled,
            FfmpegEngineSource.systemPath => l10n.customPathInvalidUsingPath,
            _ => l10n.customPathInvalid,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusChip(
                scheme.errorContainer,
                Icons.warning_amber_outlined,
                fallbackText,
                onPrimaryContainer: scheme.onErrorContainer,
                button: TextButton.icon(
                  onPressed: () =>
                      ref.read(ffmpegStatusProvider.notifier).redetect(),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.redetect),
                ),
              ),
              const SizedBox(height: 8),
              _statusChip(
                scheme.primaryContainer,
                Icons.check_circle_outline,
                l10n.ffmpegReady(s.version ?? ''),
                onPrimaryContainer: scheme.onPrimaryContainer,
              ),
            ],
          );
        }
        if (s.isReady) {
          return _statusChip(
            scheme.primaryContainer,
            Icons.check_circle_outline,
            l10n.ffmpegReady(s.version ?? ''),
            onPrimaryContainer: scheme.onPrimaryContainer,
          );
        }
        return _statusChip(
          scheme.errorContainer,
          Icons.warning_amber_outlined,
          s.errorMessage ?? l10n.ffmpegNotFound,
          onPrimaryContainer: scheme.onErrorContainer,
          button: TextButton.icon(
            onPressed: () => ref.read(ffmpegStatusProvider.notifier).redetect(),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.redetect),
          ),
        );
      },
    );
  }

  Widget _statusChip(
    Color bg,
    IconData icon,
    String text, {
    Color? onPrimaryContainer,
    Widget? button,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: onPrimaryContainer)),
          ),
          ?button,
        ],
      ),
    );
  }
}

/// 设置分组卡片。
class _SectionCard extends StatelessWidget {
  final String sectionKey;
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            key: Key('settings-content-$sectionKey'),
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }
}
