import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/utils/platform_info.dart';
import 'package:teigi/features/settings/about_card.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/app_info_provider.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/quick_formats_provider.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:teigi/theme/tokens.dart';

/// 设置页：扁平化纵向卡片流，包含转换配置、外观、行为、快捷格式以及内嵌关于信息。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final settings = ref.watch(settingsProvider);
    final ffmpegEngine = ref.watch(ffmpegEngineProvider);
    final ffmpegStatus = ref.watch(ffmpegStatusProvider);
    final quickFormats = ref.watch(quickFormatsProvider);
    final version = ref.watch(appVersionProvider);
    final scheme = Theme.of(context).colorScheme;

    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSettings),
        automaticallyImplyLeading: false,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            key: const Key('settings-body'),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ffmpegEngine.capabilities.supportsCustomExecutablePath)
                  _SectionCard(
                    isMobile: isMobile,
                    sectionKey: 'ffmpeg',
                    title: 'FFmpeg',
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
                  isMobile: isMobile,
                  sectionKey: 'conversion',
                  title: l10n.conversionSettings,
                  icon: Icons.tune,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.outputDirectory),
                      subtitle: Text(
                        settings.outputDirectory.isEmpty
                            ? (isAndroid
                                ? 'Download/Teigi (${l10n.followSystem})'
                                : l10n.sameAsSource)
                            : settings.outputDirectory,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.folder_open),
                            tooltip: l10n.browse,
                            onPressed: () => _pickOutputDirectory(ref),
                          ),
                          if (settings.outputDirectory.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: l10n.reset,
                              onPressed: () => ref
                                  .read(settingsProvider.notifier)
                                  .setOutputDirectory(''),
                            ),
                        ],
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
                  isMobile: isMobile,
                  sectionKey: 'appearance',
                  title: l10n.appearance,
                  icon: Icons.palette_outlined,
                  children: [
                    if (!isAndroid)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.languageLabel),
                        trailing: DropdownButton<String>(
                          value: L10n.supported.contains(settings.language)
                              ? settings.language
                              : 'system',
                          items: [
                            DropdownMenuItem(
                              value: 'system',
                              child: Text(l10n.followSystem),
                            ),
                            const DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                            const DropdownMenuItem(value: 'ja', child: Text('日本語')),
                            const DropdownMenuItem(value: 'en', child: Text('English')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(settingsProvider.notifier).setLanguage(v);
                            }
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 480;
                          final isVeryCompact = constraints.maxWidth < 340;
                          final button = SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: isVeryCompact ? 2 : 8)),
                              textStyle: WidgetStateProperty.all(TextStyle(fontSize: isVeryCompact ? 12 : 13)),
                            ),
                            segments: [
                              ButtonSegment(
                                value: 'system',
                                icon: isVeryCompact
                                    ? null
                                    : const Icon(Icons.brightness_auto, size: 16),
                                label: Text(l10n.followSystem),
                              ),
                              ButtonSegment(
                                value: 'light',
                                icon: isVeryCompact
                                    ? null
                                    : const Icon(Icons.light_mode_outlined, size: 16),
                                label: Text(l10n.lightMode),
                              ),
                              ButtonSegment(
                                value: 'dark',
                                icon: isVeryCompact
                                    ? null
                                    : const Icon(Icons.dark_mode_outlined, size: 16),
                                label: Text(l10n.darkMode),
                              ),
                            ],
                            selected: {settings.themeMode},
                            onSelectionChanged: (s) => ref
                                .read(settingsProvider.notifier)
                                .setThemeMode(s.first),
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.themeMode,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: button,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.themeMode,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 16),
                              button,
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                _SectionCard(
                  isMobile: isMobile,
                  sectionKey: 'behaviors',
                  title: l10n.behaviors,
                  icon: Icons.playlist_add_check_circle_outlined,
                  children: [
                    if (!isMobile)
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
                  isMobile: isMobile,
                  sectionKey: 'quick-formats',
                  title: l10n.quickFormats,
                  icon: Icons.star_outline,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.quickFormatsHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: AboutCard(key: Key('settings-about-card')),
                ),
                Center(
                  child: Text(
                    'Teigi v$version',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFfmpegPath(WidgetRef ref) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'ffmpeg',
      type: FileType.custom,
      allowedExtensions: ['exe', 'bin', ''],
    );
    if (file != null && file.path != null) {
      await ref.read(settingsProvider.notifier).setFfmpegPath(file.path!);
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
  final bool isMobile;
  final String sectionKey;
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    this.isMobile = false,
    required this.sectionKey,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: TeigiRadii.card,
          side: BorderSide(
            color: scheme.borderSubtle,
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : TeigiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                key: Key('settings-content-$sectionKey'),
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: TeigiSpacing.sm),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Divider(
                color: scheme.borderSubtle,
                height: 24,
                thickness: 1,
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
