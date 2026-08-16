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

/// Compact action card for a destination preset — an action, not a tag.
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
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      borderRadius: TeigiRadii.medium,
      child: InkWell(
        onTap: onTap,
        borderRadius: TeigiRadii.medium,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 108, minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TeigiSpacing.md,
              vertical: TeigiSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: TeigiSpacing.xxs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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
