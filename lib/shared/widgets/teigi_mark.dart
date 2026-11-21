// ignore_for_file: prefer_initializing_formals
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
///
/// Wrapped in [RepaintBoundary] to ensure hover and state transitions (e.g. InkWell highlight
/// and AnimatedContainer border/fill shifts) remain isolated to the card's own raster layer,
/// preventing parent or sibling repaints.
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
    return RepaintBoundary(
      child: Material(
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
      ),
    );
  }
}

/// A responsive preset card grid that adaptively computes column count and item widths
/// so cards always strictly fill 100% of the available horizontal width with no trailing gap.
///
/// Implemented directly as a [MultiChildRenderObjectWidget] using [RenderPresetsGrid]
/// to eliminate redundant widget rebuilds under size changes (e.g. window resize,
/// sidebar animations) by executing column distribution purely in layout.
class TeigiPresetsGrid extends MultiChildRenderObjectWidget {
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final int minColumns;
  final int maxColumns;

  const TeigiPresetsGrid({
    super.key,
    super.children = const <Widget>[],
    this.minItemWidth = 140.0,
    this.spacing = TeigiSpacing.xs,
    this.runSpacing = TeigiSpacing.xs,
    this.minColumns = 2,
    this.maxColumns = 6,
  });

  @override
  RenderPresetsGrid createRenderObject(BuildContext context) {
    return RenderPresetsGrid(
      minItemWidth: minItemWidth,
      spacing: spacing,
      runSpacing: runSpacing,
      minColumns: minColumns,
      maxColumns: maxColumns,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderPresetsGrid renderObject) {
    renderObject
      ..minItemWidth = minItemWidth
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..minColumns = minColumns
      ..maxColumns = maxColumns;
  }
}

class PresetsGridParentData extends ContainerBoxParentData<RenderBox> {}

class RenderPresetsGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, PresetsGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, PresetsGridParentData> {
  RenderPresetsGrid({
    List<RenderBox>? children,
    double minItemWidth = 140.0,
    double spacing = TeigiSpacing.xs,
    double runSpacing = TeigiSpacing.xs,
    int minColumns = 2,
    int maxColumns = 6,
  })  : _minItemWidth = minItemWidth,
        _spacing = spacing,
        _runSpacing = runSpacing,
        _minColumns = minColumns,
        _maxColumns = maxColumns {
    addAll(children);
  }

  double _minItemWidth;
  double get minItemWidth => _minItemWidth;
  set minItemWidth(double value) {
    if (_minItemWidth == value) return;
    _minItemWidth = value;
    markNeedsLayout();
  }

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  int _minColumns;
  int get minColumns => _minColumns;
  set minColumns(int value) {
    if (_minColumns == value) return;
    _minColumns = value;
    markNeedsLayout();
  }

  int _maxColumns;
  int get maxColumns => _maxColumns;
  set maxColumns(int value) {
    if (_maxColumns == value) return;
    _maxColumns = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! PresetsGridParentData) {
      child.parentData = PresetsGridParentData();
    }
  }

  ({int cols, double itemWidth}) _calculateMetrics(double maxWidth) {
    final effectiveMinCols = (maxWidth < 250) ? 1 : minColumns;
    final rawCols = ((maxWidth + spacing) / (minItemWidth + spacing)).floor();
    final cols = rawCols.clamp(effectiveMinCols, maxColumns);
    final rawItemWidth = (maxWidth - (cols - 1) * spacing) / cols;
    final itemWidth = rawItemWidth > 0 ? rawItemWidth : 0.0;
    return (cols: cols, itemWidth: itemWidth);
  }

  @override
  void performLayout() {
    if (firstChild == null) {
      size = constraints.smallest;
      return;
    }

    final hasBoundedWidth = constraints.hasBoundedWidth && constraints.maxWidth > 0;
    final double w = hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;

    final int cols;
    final double itemWidth;
    final double contentWidth;
    if (!hasBoundedWidth || w <= 0) {
      cols = minColumns.clamp(1, maxColumns);
      itemWidth = minItemWidth;
      contentWidth = itemWidth * cols + (cols > 1 ? (cols - 1) * spacing : 0.0);
    } else {
      final metrics = _calculateMetrics(w);
      cols = metrics.cols;
      itemWidth = metrics.itemWidth;
      contentWidth = w;
    }

    final childConstraints = BoxConstraints.tightFor(width: itemWidth);

    double currentX = 0.0;
    double currentY = 0.0;
    double currentRowHeight = 0.0;
    int currentCol = 0;

    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData = child.parentData! as PresetsGridParentData;
      child.layout(childConstraints, parentUsesSize: true);

      if (currentCol >= cols && currentCol > 0) {
        currentY += currentRowHeight + runSpacing;
        currentX = 0.0;
        currentRowHeight = 0.0;
        currentCol = 0;
      }

      childParentData.offset = Offset(currentX, currentY);
      if (child.size.height > currentRowHeight) {
        currentRowHeight = child.size.height;
      }

      currentX += itemWidth + spacing;
      currentCol++;

      child = childParentData.nextSibling;
    }

    final totalHeight = currentY + currentRowHeight;
    size = constraints.constrain(Size(contentWidth, totalHeight));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (firstChild == null) {
      return constraints.smallest;
    }

    final hasBoundedWidth = constraints.hasBoundedWidth && constraints.maxWidth > 0;
    final double w = hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;

    final int cols;
    final double itemWidth;
    final double contentWidth;
    if (!hasBoundedWidth || w <= 0) {
      cols = minColumns.clamp(1, maxColumns);
      itemWidth = minItemWidth;
      contentWidth = itemWidth * cols + (cols > 1 ? (cols - 1) * spacing : 0.0);
    } else {
      final metrics = _calculateMetrics(w);
      cols = metrics.cols;
      itemWidth = metrics.itemWidth;
      contentWidth = w;
    }

    final childConstraints = BoxConstraints.tightFor(width: itemWidth);

    double currentY = 0.0;
    double currentRowHeight = 0.0;
    int currentCol = 0;

    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData = child.parentData! as PresetsGridParentData;
      final childSize = child.getDryLayout(childConstraints);

      if (currentCol >= cols && currentCol > 0) {
        currentY += currentRowHeight + runSpacing;
        currentRowHeight = 0.0;
        currentCol = 0;
      }

      if (childSize.height > currentRowHeight) {
        currentRowHeight = childSize.height;
      }

      currentCol++;
      child = childParentData.nextSibling;
    }

    final totalHeight = currentY + currentRowHeight;
    return constraints.constrain(Size(contentWidth, totalHeight));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (firstChild == null) return 0.0;
    return minItemWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (firstChild == null) return 0.0;
    return minItemWidth * maxColumns + spacing * (maxColumns - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (firstChild == null) return 0.0;
    return computeDryLayout(BoxConstraints(maxWidth: width)).height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (firstChild == null) return 0.0;
    return computeDryLayout(BoxConstraints(maxWidth: width)).height;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
