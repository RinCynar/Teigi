import 'package:flutter/material.dart';
import 'package:teigi/theme/tokens.dart';

/// Material 3 theme built from a seed. All colors come from [ColorScheme].
class TeigiTheme {
  static const seedLight = TeigiColors.seed;
  static const seedDark = TeigiColors.seed;

  static String fontFamilyFor(String? language) {
    return switch (language) {
      'zh' => 'NotoSansSC',
      'ja' => 'NotoSansJP',
      _ => 'NotoSans',
    };
  }

  static ThemeData light({
    ColorScheme? colorScheme,
    Color seed = seedLight,
    String? language,
  }) {
    final baseScheme = colorScheme ??
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        );
    final scheme = colorScheme != null
        ? baseScheme
        : baseScheme.copyWith(
            primary: const Color(0xFF006A6B),
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFF70F7EC),
            onPrimaryContainer: const Color(0xFF002021),
            secondary: const Color(0xFF4A6363),
            secondaryContainer: const Color(0xFFCCE8E7),
            onSecondaryContainer: const Color(0xFF051F20),
            surface: const Color(0xFFF4FBFA),
            onSurface: const Color(0xFF161D1D),
            surfaceContainerLowest: const Color(0xFFFFFFFF),
            surfaceContainerLow: const Color(0xFFEFF5F4),
            surfaceContainer: const Color(0xFFE9EFEF),
            surfaceContainerHigh: const Color(0xFFE3EAE9),
            surfaceContainerHighest: const Color(0xFFDEE4E3),
            outline: const Color(0xFF6F7979),
            outlineVariant: const Color(0xFFBEC9C8),
          );
    return _base(scheme, fontFamily: fontFamilyFor(language));
  }

  static ThemeData dark({
    ColorScheme? colorScheme,
    Color seed = seedDark,
    String? language,
  }) {
    final baseScheme = colorScheme ??
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        );
    final scheme = colorScheme != null
        ? baseScheme
        : baseScheme.copyWith(
            primary: const Color(0xFF39C5BB),
            onPrimary: const Color(0xFF003738),
            primaryContainer: const Color(0xFF004F50),
            onPrimaryContainer: const Color(0xFF70F7EC),
            secondary: const Color(0xFFB0CCCB),
            secondaryContainer: const Color(0xFF324B4B),
            onSecondaryContainer: const Color(0xFFCCE8E7),
            surface: const Color(0xFF0E1514),
            onSurface: const Color(0xFFDEE4E3),
            surfaceContainerLowest: const Color(0xFF090F0F),
            surfaceContainerLow: const Color(0xFF161D1D),
            surfaceContainer: const Color(0xFF1A2121),
            surfaceContainerHigh: const Color(0xFF252B2B),
            surfaceContainerHighest: const Color(0xFF303636),
            outline: const Color(0xFF889392),
            outlineVariant: const Color(0xFF3F4948),
          );
    return _base(scheme, fontFamily: fontFamilyFor(language));
  }

  static const List<String> fontFallbacks = [
    'Microsoft YaHei',
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans CJK SC',
    'WenQuanYi Micro Hei',
    'sans-serif',
  ];

  static ThemeData _base(ColorScheme scheme, {required String fontFamily}) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallbacks,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        height: 72,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: TeigiRadii.card,
          side: BorderSide(
            color: scheme.borderSubtle,
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: TeigiRadii.dialog,
          side: BorderSide(
            color: scheme.borderSubtle,
            width: 1,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: TeigiRadii.medium),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.borderSubtle,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: TeigiRadii.field,
          borderSide: BorderSide(color: scheme.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TeigiRadii.field,
          borderSide: BorderSide(color: scheme.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TeigiRadii.field,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: TeigiRadii.large),
      ),
    );
  }
}
