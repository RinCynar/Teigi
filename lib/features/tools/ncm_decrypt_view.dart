import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:teigi/core/ncm/ncm_decryptor.dart';
import 'package:teigi/core/utils/file_identity.dart';
import 'package:teigi/core/utils/open_path.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:teigi/shared/layout/content_constraint.dart';
import 'package:teigi/theme/tokens.dart';

enum NcmItemStatus { pending, processing, completed, failed }

class NcmTaskItem {
  final String id;
  final String sourcePath;
  final String fileName;
  final int fileSize;
  NcmItemStatus status;
  double progress;
  NcmDecryptionResult? result;
  String? error;

  NcmTaskItem({
    required this.id,
    required this.sourcePath,
    required this.fileName,
    required this.fileSize,
    this.status = NcmItemStatus.pending,
    this.progress = 0.0,
    this.result,
    this.error,
  });
}

class NcmDecryptView extends ConsumerStatefulWidget {
  const NcmDecryptView({super.key});

  @override
  ConsumerState<NcmDecryptView> createState() => _NcmDecryptViewState();
}

class _NcmDecryptViewState extends ConsumerState<NcmDecryptView> {
  final List<NcmTaskItem> _items = [];
  bool _isRunning = false;
  bool _cancelRequested = false;
  String? _customOutputDir;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final size = TeigiBreakpoints.sizeOf(width);

    final effectiveOutputDir = _customOutputDir ??
        (settings.outputDirectory.isNotEmpty ? settings.outputDirectory : null);

    final pendingCount = _items.where((i) => i.status == NcmItemStatus.pending).length;
    final completedCount = _items.where((i) => i.status == NcmItemStatus.completed).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: (details) {
            setState(() => _isDragging = false);
            final paths = [
              for (final f in details.files)
                if (f.path.toLowerCase().endsWith('.ncm')) f.path,
            ];
            _addFiles(paths);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _isDragging
                  ? scheme.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: ContentConstraint(
              padding: EdgeInsets.fromLTRB(
                size == TeigiWindowSize.compact ? TeigiSpacing.md : TeigiSpacing.page,
                TeigiSpacing.lg,
                size == TeigiWindowSize.compact ? TeigiSpacing.md : TeigiSpacing.page,
                TeigiSpacing.page,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header with back button & title
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        onPressed: () => context.go('/tools'),
                      ),
                      const SizedBox(width: TeigiSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.toolNcmTitle,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              l10n.toolNcmDesc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (_items.isNotEmpty && !_isRunning)
                        TextButton(
                          onPressed: () => setState(() => _items.clear()),
                          child: Text(l10n.clearCompleted),
                        ),
                      const SizedBox(width: TeigiSpacing.xs),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isRunning ? null : _pickNcmFiles,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(l10n.addFiles),
                      ),
                    ],
                  ),
                  const SizedBox(height: TeigiSpacing.md),

                  // 2. Output directory selector bar
                  _buildOutputDirBar(effectiveOutputDir, scheme, l10n),
                  const SizedBox(height: TeigiSpacing.md),

                  // 3. Main content: Empty state or File list
                  Expanded(
                    child: _items.isEmpty
                        ? _buildEmptyState(scheme, l10n)
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: TeigiSpacing.sm),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return _buildFileItemCard(item, scheme, l10n);
                            },
                          ),
                  ),

                  // 4. Bottom action panel
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: TeigiSpacing.md),
                    _buildBottomBar(pendingCount, completedCount, scheme, l10n),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutputDirBar(String? effectiveOutputDir, ColorScheme scheme, L10n l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.outputDirectory,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  effectiveOutputDir ?? l10n.sourceDir,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          if (effectiveOutputDir != null) ...[
            IconButton(
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              tooltip: l10n.openFolder,
              onPressed: () => openLocalPath(effectiveOutputDir),
            ),
            const SizedBox(width: 4),
          ],
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: scheme.borderSubtle),
            ),
            onPressed: _pickOutputDirectory,
            child: Text(l10n.changeDir),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme, L10n l10n) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(TeigiSpacing.xxl),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.borderSubtle, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_open_rounded, size: 30, color: scheme.primary),
            ),
            const SizedBox(height: TeigiSpacing.md),
            Text(
              l10n.dropNcmHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: TeigiSpacing.xs),
            Text(
              l10n.ncmEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: TeigiSpacing.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _pickNcmFiles,
              icon: const Icon(Icons.file_upload_outlined, size: 20),
              label: Text(l10n.addNcmFiles),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItemCard(NcmTaskItem item, ColorScheme scheme, L10n l10n) {
    final title = item.result?.musicTitle ?? item.fileName;
    final sizeText = FileIdentity.sizeLabel(item.sourcePath) ?? '${item.fileSize} B';
    final subtitle = item.result != null && item.result!.artists.isNotEmpty
        ? '${item.result!.artistDisplay} · $sizeText'
        : sizeText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.status == NcmItemStatus.processing
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.borderSubtle,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Cover or Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.result?.coverBytes != null && item.result!.coverBytes!.isNotEmpty
                ? Image.memory(item.result!.coverBytes!, fit: BoxFit.cover)
                : Icon(
                    Icons.music_note_rounded,
                    color: scheme.primary,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 14),
          // Title & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (item.status == NcmItemStatus.processing) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: item.progress > 0 ? item.progress : null,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 4,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Status & Actions
          _buildStatusWidget(item, scheme, l10n),
          if (!_isRunning && item.status != NcmItemStatus.processing) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => _items.remove(item)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusWidget(NcmTaskItem item, ColorScheme scheme, L10n l10n) {
    switch (item.status) {
      case NcmItemStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            l10n.queued,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        );
      case NcmItemStatus.processing:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${(item.progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
            ),
          ),
        );
      case NcmItemStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (item.result?.format ?? 'MP3').toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (item.result?.outputPath != null)
              IconButton(
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                tooltip: l10n.openFolder,
                onPressed: () => openParentFolder(item.result!.outputPath!),
              ),
          ],
        );
      case NcmItemStatus.failed:
        return Tooltip(
          message: item.error ?? l10n.decryptFailed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 14, color: scheme.onErrorContainer),
                const SizedBox(width: 4),
                Text(
                  l10n.decryptFailed,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildBottomBar(int pendingCount, int completedCount, ColorScheme scheme, L10n l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.album_outlined,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_items.length} 个任务 · $completedCount 已完成 · $pendingCount 待解密',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (_isRunning)
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => setState(() => _cancelRequested = true),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(l10n.cancel),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: pendingCount == 0 ? null : _startBatchDecryption,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(l10n.startDecrypt),
            ),
        ],
      ),
    );
  }

  Future<void> _pickNcmFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ncm'],
    );
    if (result.isNotEmpty) {
      final valid = [
        for (final p in result)
          if (p.path != null) p.path!,
      ];
      _addFiles(valid);
    }
  }

  void _addFiles(List<String> paths) {
    final existing = _items.map((i) => i.sourcePath).toSet();
    final newItems = <NcmTaskItem>[];

    for (final path in paths) {
      if (existing.contains(path)) continue;
      final file = File(path);
      if (!file.existsSync()) continue;

      newItems.add(
        NcmTaskItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}',
          sourcePath: path,
          fileName: p.basename(path),
          fileSize: file.lengthSync(),
        ),
      );
    }

    if (newItems.isNotEmpty) {
      setState(() => _items.addAll(newItems));
    }
  }

  Future<void> _pickOutputDirectory() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null && mounted) {
      setState(() => _customOutputDir = path);
    }
  }

  Future<void> _startBatchDecryption() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _cancelRequested = false;
    });

    final settings = ref.read(settingsProvider);

    for (final item in _items) {
      if (_cancelRequested) break;
      if (item.status != NcmItemStatus.pending && item.status != NcmItemStatus.failed) {
        continue;
      }

      setState(() {
        item.status = NcmItemStatus.processing;
        item.progress = 0.0;
        item.error = null;
      });

      final outDir = _customOutputDir ??
          (settings.outputDirectory.isNotEmpty
              ? settings.outputDirectory
              : p.dirname(item.sourcePath));

      final result = await NcmDecryptor.decryptFile(
        NcmDecryptRequest(
          sourcePath: item.sourcePath,
          outputDirectory: outDir,
        ),
        onProgress: (progress) {
          if (mounted) {
            setState(() => item.progress = progress);
          }
        },
      );

      if (!mounted) break;

      setState(() {
        if (result.success) {
          item.status = NcmItemStatus.completed;
          item.result = result;
          item.progress = 1.0;
        } else {
          item.status = NcmItemStatus.failed;
          item.error = result.error;
        }
      });
    }

    if (mounted) {
      setState(() => _isRunning = false);
    }
  }
}
