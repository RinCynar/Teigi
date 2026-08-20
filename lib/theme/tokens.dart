import 'package:flutter/material.dart';

/// Spacing scale. Layout should use these values only.
abstract final class TeigiSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;

  static const double page = xl;
  static const double section = xl;
  static const double card = lg;
  static const double item = sm;
  static const double iconText = xs;
}

/// Material 3 shape tokens.
abstract final class TeigiRadii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static BorderRadius get extraSmall => BorderRadius.circular(xs);
  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
  static BorderRadius get extraLarge => BorderRadius.circular(xxl);

  static BorderRadius get button => BorderRadius.circular(xl);
  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get dialog => extraLarge;
  static BorderRadius get field => BorderRadius.circular(md);
  static BorderRadius get fileItem => BorderRadius.circular(lg);
}

/// Adaptive breakpoints. Content should not stretch past [maxContent].
abstract final class TeigiBreakpoints {
  static const double compact = 600;
  static const double expanded = 1024;
  static const double maxContent = 1120;
  static const double configSheet = 360;

  static TeigiWindowSize sizeOf(double width) {
    if (width < compact) return TeigiWindowSize.compact;
    if (width < expanded) return TeigiWindowSize.medium;
    return TeigiWindowSize.expanded;
  }
}

enum TeigiWindowSize { compact, medium, expanded }

/// Motion should stay fast and interruptible.
abstract final class TeigiMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 220);
}

/// Default brand seed: Miku teal fallback.
abstract final class TeigiColors {
  static const Color seed = Color(0xFF39C5BB);
}
