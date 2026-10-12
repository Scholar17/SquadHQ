import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Text styles: Caprasimo for big display headings, Figtree for
/// everything else — Caprasimo's chunky serifs get hard to read small.
///
/// [color] defaults to null so text inherits its surroundings: the
/// theme's [AppColors.text] on cream, a button's foreground (and its
/// disabled shade) inside a button, light text in a snackbar. A fixed
/// default overrode those — dark text on the dark hero card.
abstract final class AppTextStyles {
  /// Below this, a heading is a [title] instead.
  static const displayMinSize = 20.0;

  /// Hero and page headings (20px and up): amounts, scores, "Settle up".
  static TextStyle heading({double size = 28, Color? color, double height = 1.05}) {
    assert(
      size >= displayMinSize,
      'Caprasimo is for display sizes ($displayMinSize+); use AppTextStyles.title for $size.',
    );
    return GoogleFonts.caprasimo(fontSize: size, color: color, height: height, letterSpacing: -0.2);
  }

  /// Card, section, sheet and app-bar titles (14–18px).
  static TextStyle title({double size = 16, Color? color, double height = 1.2}) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: height,
        letterSpacing: -0.1,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.5,
  }) => GoogleFonts.figtree(fontSize: size, fontWeight: weight, color: color, height: height);

  /// Small caps-style labels and badges ("YOU PAY", "TO CONFIRM").
  static TextStyle label({double size = 11, Color? color}) => GoogleFonts.figtree(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: 0.5,
  );
}
