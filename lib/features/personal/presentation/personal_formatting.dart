import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../match/presentation/match_formatting.dart' show monthNames, weekdayNames;
import '../domain/entities/spending_report.dart';

/// A category's icon by its key (a built-in's name, or `custom:<id>`).
IconData personalCategoryIcon(String categoryKey) => switch (categoryKey) {
  'food' => Icons.restaurant_rounded,
  'transport' => Icons.local_taxi_outlined,
  'sports' => Icons.sports_soccer_outlined,
  'shopping' => Icons.shopping_bag_outlined,
  'bills' => Icons.receipt_outlined,
  'other' => Icons.receipt_long_outlined,
  _ => Icons.label_outline_rounded,
};

/// A category's colour pair for its icon tile, like the squad's: a
/// [background] wash and the [foreground] icon. Your own categories share
/// one hue — the name tells them apart.
({Color background, Color foreground}) personalCategoryTone(String categoryKey) =>
    switch (categoryKey) {
      'food' => (background: AppColors.accent100, foreground: AppColors.accent700),
      'transport' => (background: AppColors.categoryBlueBg, foreground: AppColors.categoryBlue),
      'sports' => (background: AppColors.accent2_100, foreground: AppColors.accent2_700),
      'shopping' => (background: AppColors.categoryRoseBg, foreground: AppColors.categoryRose),
      'bills' => (background: AppColors.categoryGoldBg, foreground: AppColors.categoryGold),
      'other' => (background: AppColors.neutral200, foreground: AppColors.neutral700),
      _ => (background: AppColors.categoryPlumBg, foreground: AppColors.categoryPlum),
    };

/// "Today", "Yesterday", or "Wed 18 Nov 2026".
String formatDayLabel(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final today = now ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  if (day == todayDay) return 'Today';
  if (day == todayDay.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${weekdayNames[local.weekday - 1]} ${local.day} ${monthNames[local.month - 1]} ${local.year}';
}

/// "18 Nov 2026".
String formatDate(DateTime at) => '${at.day} ${monthNames[at.month - 1]} ${at.year}';

/// What a report covers: "Wed 18 Nov 2026", "November 2026", "2026", or
/// "1 Nov – 18 Nov 2026".
String formatWindow(ReportPeriod period, ReportWindow window) {
  final start = window.start;
  final last = window.end.subtract(const Duration(days: 1));
  return switch (period) {
    ReportPeriod.day =>
      '${weekdayNames[start.weekday - 1]} ${start.day} ${monthNames[start.month - 1]} ${start.year}',
    ReportPeriod.month => '${_monthLong[start.month - 1]} ${start.year}',
    ReportPeriod.year => '${start.year}',
    ReportPeriod.range when start.year == last.year =>
      '${start.day} ${monthNames[start.month - 1]} – ${formatDate(last)}',
    ReportPeriod.range => '${formatDate(start)} – ${formatDate(last)}',
  };
}

/// "Nov".
String monthShort(DateTime month) => monthNames[month.month - 1];

const _monthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
