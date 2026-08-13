import 'package:flutter/material.dart';

/// 应用主题：Material 3 + 动态色彩（ColorScheme.fromSeed）。
///
/// 支持：
/// - 浅色 / 深色模式跟随系统或手动指定
/// - 用户自定义种子色（Material You 动态色）
/// - 按语言内嵌字体（zh→NotoSansSC / ja→NotoSansJP / 其他→NotoSans）
class TeigiTheme {
  static const seedLight = Color(0xFF6750A4);
  static const seedDark = Color(0xFFD0BCFF);

  /// 根据语言代码返回对应字体族（仅嵌入 Regular 字重）。
  static String fontFamilyFor(String? language) {
    return switch (language) {
      'zh' => 'NotoSansSC',
      'ja' => 'NotoSansJP',
      _ => 'NotoSans',
    };
  }

  /// 生成完整的 [ThemeData]。
  static ThemeData light({Color seed = seedLight, String? language}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return _base(scheme, fontFamily: fontFamilyFor(language));
  }

  static ThemeData dark({Color seed = seedDark, String? language}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return _base(scheme, fontFamily: fontFamilyFor(language));
  }

  static ThemeData _base(ColorScheme scheme, {required String fontFamily}) {
    final color = scheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: color,
      scaffoldBackgroundColor: color.surface,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: color.surfaceContainer,
        foregroundColor: color.onSurface,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: color.surfaceContainerLow,
        indicatorColor: color.secondaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: color.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: color.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
