import 'package:flutter/material.dart';
import 'package:teigi/theme/tokens.dart';

/// Keeps reading width reasonable on ultrawide / 4K displays.
class ContentConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = TeigiBreakpoints.maxContent,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
  }
}
