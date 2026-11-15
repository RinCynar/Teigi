import 'package:flutter/material.dart';
import 'package:teigi/theme/tokens.dart';

/// Simple Teigi glyph: a geometric T. Not the Flutter logo.
class TeigiMark extends StatelessWidget {
  final double size;

  const TeigiMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Teigi',
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: CustomPaint(
            painter: _TeigiMarkPainter(color: scheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}

class _TeigiMarkPainter extends CustomPainter {
  final Color color;

  _TeigiMarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.14;
    final pad = size.width * 0.26;
    final top = size.height * 0.30;
    final bottom = size.height * 0.74;
    canvas.drawLine(Offset(pad, top), Offset(size.width - pad, top), paint);
    canvas.drawLine(
      Offset(size.width / 2, top),
      Offset(size.width / 2, bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TeigiMarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Compact action card for a destination preset — an entity card with subtle border & state layer.
class TeigiPresetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const TeigiPresetCard({
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

/// A responsive preset card grid that adaptively computes column count and item widths
/// so cards always strictly fill 100% of the available horizontal width with no trailing gap.
class TeigiPresetsGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final int minColumns;
  final int maxColumns;

  const TeigiPresetsGrid({
    super.key,
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

