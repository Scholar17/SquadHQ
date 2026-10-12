import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Elevation: soft, warm shadows tinted with the brand ink, never grey —
/// and deeper at night, where a faint ink shadow wouldn't show.
abstract final class AppShadows {
  static Color get _ink => AppColors.palette.shadow;
  static double get _depth => AppColors.isDark ? 3 : 1;

  /// A hint of lift — list cards on cream.
  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: _ink.withValues(alpha: 0.06 * _depth),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
  ];

  /// Cards that matter: two layers, a tight contact shadow and a soft
  /// ambient one.
  static List<BoxShadow> get elevatedCard => [
    BoxShadow(
      color: _ink.withValues(alpha: 0.06 * _depth),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: _ink.withValues(alpha: 0.08 * _depth),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  /// The dark hero cards: a warm gold glow under the card.
  static List<BoxShadow> get darkHeroGlow => [
    BoxShadow(
      // At night a strong glow reads as a slab under the card.
      color: AppColors.teamGold.withValues(alpha: AppColors.isDark ? 0.05 : 0.2),
      blurRadius: 28,
      offset: Offset(0, AppColors.isDark ? 6 : 12),
    ),
    BoxShadow(
      color: _ink.withValues(alpha: 0.15 * _depth),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];
}
