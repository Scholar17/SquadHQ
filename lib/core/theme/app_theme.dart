import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        surface: AppColors.bg,
        primary: AppColors.accent,
        secondary: AppColors.accent2,
      ),
      fontFamily: GoogleFonts.figtree().fontFamily,
    );
    return base.copyWith(
      textTheme: GoogleFonts.figtreeTextTheme(base.textTheme),
    );
  }
}
