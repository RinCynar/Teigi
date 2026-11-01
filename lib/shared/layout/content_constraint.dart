import 'package:flutter/material.dart';
import 'package:teigi/theme/tokens.dart';

/// 响应式内容约束容器：在桌面超宽屏上限制最大阅读宽度，在移动端窄屏上自动适配边距。
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
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: isMobile ? TeigiSpacing.md : TeigiSpacing.page,
          vertical: isMobile ? TeigiSpacing.md : TeigiSpacing.page,
        );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: effectivePadding, child: child),
      ),
    );
  }
}
