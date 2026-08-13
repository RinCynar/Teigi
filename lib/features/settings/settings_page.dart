import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/quick_formats_provider.dart';
import 'package:teigi/providers/settings_provider.dart';

/// 设置页：ffmpeg 路径、输出目录、并发、主题、快捷格式等。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final settings = ref.watch(settingsProvider);
    final ffmpegStatus = ref.watch(ffmpegStatusProvider);
    final quickFormats = ref.watch(quickFormatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSettings),
        // 使用 go_router 返回，避免与路由栈不一致导致黑屏。
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'ffmpeg',
            icon: Icons.movie_filter_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.ffmpegPathTitle),
                subtitle: Text(
                  settings.ffmpegPath.isEmpty
                      ? l10n.usePathFfmpeg
                      : settings.ffmpegPath,
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
                        onPressed: () =>
                            ref.read(settingsProvider.notifier).setFfmpegPath(''),
                      ),
                  ],
                ),
              ),
              _StatusRow(ffmpegStatus: ffmpegStatus),
            ],
          ),
          _SectionCard(
            title: l10n.conversionSettings,
            icon: Icons.tune,
            children: [
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
                value: settings.hardwareAccel,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setHardwareAccel(v),
              ),
            ],
          ),
          _SectionCard(
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
                    ButtonSegment(value: 'system', label: Text(l10n.followSystem)),
                    ButtonSegment(value: 'light', label: Text(l10n.lightMode)),
                    ButtonSegment(value: 'dark', label: Text(l10n.darkMode)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => ref
                      .read(settingsProvider.notifier)
                      .setThemeMode(s.first),
                ),
              ),
              _SeedColorTile(l10n: l10n, settings: settings),
            ],
          ),
          _SectionCard(
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
                      ref.read(settingsProvider.notifier).update(
                            settings.copyWith(overwritePolicy: v),
                          );
                    }
                  },
                ),
              ),
            ],
          ),
          _SectionCard(
            title: l10n.quickFormats,
            icon: Icons.star_outline,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.quickFormatsHint,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                        onDeleted: () =>
                            ref.read(quickFormatsProvider.notifier).remove(f.extension),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Teigi v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        ],
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

  Future<void> _pickOutputDirectory(WidgetRef ref) async {
    final l10n = ref.read(l10nProvider);
    final path = await FilePicker.getDirectoryPath(dialogTitle: l10n.outputDirectory);
    if (path != null) {
      await ref.read(settingsProvider.notifier).setOutputDirectory(path);
    }
  }
}

/// 种子颜色设置行：预设色板 + 十六进制输入。
class _SeedColorTile extends ConsumerWidget {
  final L10n l10n;
  final AppSettings settings;

  const _SeedColorTile({required this.l10n, required this.settings});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: _toHex(settings.seedColor));
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
                  onTap: () => ref.read(settingsProvider.notifier).setSeedColor(c),
                  child: CircleAvatar(
                    backgroundColor: c,
                    radius: 16,
                    child: c == settings.seedColor
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
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
                  controller: controller,
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
                      ref.read(settingsProvider.notifier).setSeedColor(
                            Color(0xFF000000 | color),
                          );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.seedColorHint,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
  final AsyncValue<FfmpegStatus> ffmpegStatus;

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
        if (s.isAvailable) {
          return _statusChip(
            scheme.primaryContainer,
            Icons.check_circle_outline,
            l10n.ffmpegReady(s.info.version),
            onPrimaryContainer: scheme.onPrimaryContainer,
          );
        }
        return _statusChip(
          scheme.errorContainer,
          Icons.warning_amber_outlined,
          s.message ?? l10n.ffmpegNotFound,
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
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

