import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Text styles matching the prototype's Caprasimo (heading) / Figtree
/// (body) pairing.
abstract final class AppTextStyles {
  static TextStyle heading({
    double size = 28,
    Color color = AppColors.text,
    double height = 1.05,
  }) =>
      GoogleFonts.caprasimo(
        fontSize: size,
        color: color,
        height: height,
        letterSpacing: -0.2,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.text,
    double height = 1.5,
  }) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle label({
    double size = 11,
    Color color = AppColors.text,
  }) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 1.1,
      );
}
