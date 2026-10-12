import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(AppPalette.light);

  /// Midnight pitch.
  static ThemeData get dark => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: p.brightness,
        surface: p.bg,
        primary: AppColors.accent,
        onPrimary: AppColors.onDark,
        secondary: AppColors.accent2,
        // Default text, list tiles, dialogs and fields: the brand ink.
        onSurface: p.text,
        onSurfaceVariant: p.textMuted,
        outline: p.divider,
      ),
      fontFamily: GoogleFonts.figtree().fontFamily,
    );
    return base.copyWith(
      // Inherited by AppTextStyles, which set no colour of their own.
      textTheme: GoogleFonts.figtreeTextTheme(base.textTheme)
          .apply(bodyColor: p.text, displayColor: p.text),
      // The defaults screens get without asking — the same tokens the
      // hand-built ones use.
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.title(size: 17, color: p.text),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
        titleTextStyle: AppTextStyles.title(size: 18, color: p.text),
        contentTextStyle: AppTextStyles.body(color: p.textMuted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      chipTheme: base.chipTheme.copyWith(shape: const StadiumBorder()),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.inverse,
        contentTextStyle: AppTextStyles.body(color: AppColors.onDark),
      ),
      dividerColor: p.divider,
    );
  }
}
