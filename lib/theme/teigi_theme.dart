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
    final scheme = colorScheme ??
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        );
    return _base(scheme, fontFamily: fontFamilyFor(language));
  }

  static ThemeData dark({
    ColorScheme? colorScheme,
    Color seed = seedDark,
    String? language,
  }) {
    final scheme = colorScheme ??
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
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
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        height: 72,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: TeigiRadii.card),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: TeigiRadii.dialog),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: TeigiRadii.medium),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: TeigiRadii.field),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: TeigiRadii.button),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: TeigiRadii.button),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: RoundedRectangleBorder(borderRadius: TeigiRadii.button),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: TeigiRadii.large),
      ),
    );
  }
}
