import 'package:flutter/material.dart';
import 'package:teigi/theme/tokens.dart';

/// Large, obvious drop target. Highlight is a filled surface, not just a border.
class TeigiDropZone extends StatelessWidget {
  final bool highlighted;
  final VoidCallback onAddFiles;
  final VoidCallback? onAddFolder;
  final String title;
  final String actionLabel;
  final String? folderLabel;
  final String formatsLabel;

  const TeigiDropZone({
    super.key,
    required this.highlighted,
    required this.onAddFiles,
    this.onAddFolder,
    required this.title,
    required this.actionLabel,
    this.folderLabel,
    required this.formatsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = highlighted
        ? scheme.primaryContainer
        : scheme.surfaceContainerLow;
    final onFill = highlighted
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: TeigiMotion.fast,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(TeigiSpacing.xxl),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: TeigiRadii.card,
        border: Border.all(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            highlighted ? Icons.file_download_outlined : Icons.add_circle_outline,
            size: 48,
            color: onFill,
          ),
          const SizedBox(height: TeigiSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: highlighted ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
          ),
          const SizedBox(height: TeigiSpacing.lg),
          Wrap(
            spacing: TeigiSpacing.xs,
            runSpacing: TeigiSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onAddFiles,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
              ),
              if (onAddFolder != null && folderLabel != null)
                OutlinedButton.icon(
                  onPressed: onAddFolder,
                  icon: const Icon(Icons.folder_open),
                  label: Text(folderLabel!),
                ),
            ],
          ),
          const SizedBox(height: TeigiSpacing.md),
          Text(
            formatsLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onFill),
          ),
        ],
      ),
    );
  }
}
