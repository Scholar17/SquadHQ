import 'package:flutter/painting.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

/// Whole-surface decorations shared by more than one card.
abstract final class AppDecorations {
  /// The dark hero cards (balances, matchday): ink with a warm gold light
  /// pooling in from the top-left corner, and the gold glow underneath.
  static BoxDecoration darkHero({BorderRadius borderRadius = AppRadius.xl}) => BoxDecoration(
    borderRadius: borderRadius,
    gradient: RadialGradient(
      center: const Alignment(-0.9, -1.1),
      radius: 1.4,
      colors: [
        Color.alphaBlend(AppColors.teamGold.withValues(alpha: 0.16), AppColors.neutral900),
        AppColors.neutral900,
      ],
    ),
    boxShadow: AppShadows.darkHeroGlow,
  );
}
