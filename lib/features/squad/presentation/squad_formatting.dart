import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../match/presentation/match_formatting.dart';
import '../../team_membership/domain/entities/team.dart';
import '../domain/entities/expense.dart';

String _withCommas(String digits) =>
    digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Minor units as money — whole when it is (฿1,200), to the satang when it
/// isn't (฿287.50).
String formatMoney(int cents, GroupCurrency currency) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final whole = _withCommas((abs ~/ 100).toString());
  final fraction = abs % 100;
  return fraction == 0
      ? '$sign${currency.symbol}$whole'
      : '$sign${currency.symbol}$whole.${fraction.toString().padLeft(2, '0')}';
}

/// Always to the minor unit, e.g. ฿333.33 — the "exact" line under a
/// rounded share.
String formatMoneyExact(int cents, GroupCurrency currency) {
  final whole = _withCommas((cents.abs() ~/ 100).toString());
  return '${cents < 0 ? '-' : ''}${currency.symbol}$whole.${(cents.abs() % 100).toString().padLeft(2, '0')}';
}

/// Typed text ("1,150.5") to minor units, or null if it isn't a number.
int? parseMoney(String text) {
  final cleaned = text.replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

/// Minor units back to editable text, grouped like [MoneyInputFormatter]
/// types it: "1,150" or "287.50".
String moneyInput(int cents) {
  final whole = _withCommas((cents ~/ 100).toString());
  if (cents % 100 == 0) return whole;
  return '$whole.${(cents % 100).toString().padLeft(2, '0')}';
}

/// "Fri 27 Sep".
String formatShortDate(DateTime at) {
  final local = at.toLocal();
  return '${weekdayNames[local.weekday - 1]} ${local.day} ${monthNames[local.month - 1]}';
}

const _monthNamesLong = [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];

/// "SEPTEMBER 2026".
String formatMonthLabel(DateTime at) {
  final local = at.toLocal();
  return '${_monthNamesLong[local.month - 1]} ${local.year}';
}

IconData categoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.food => Icons.restaurant_rounded,
  ExpenseCategory.drinks => Icons.local_bar_rounded,
  ExpenseCategory.shopping => Icons.shopping_bag_outlined,
  ExpenseCategory.transport => Icons.local_taxi_outlined,
  ExpenseCategory.stay => Icons.hotel_outlined,
  ExpenseCategory.tickets => Icons.confirmation_number_outlined,
  ExpenseCategory.other => Icons.receipt_long_outlined,
  ExpenseCategory.youtube => Icons.smart_display_outlined,
  ExpenseCategory.netflix => Icons.movie_outlined,
  ExpenseCategory.spotify => Icons.music_note_outlined,
  ExpenseCategory.canva => Icons.palette_outlined,
  ExpenseCategory.chatgpt => Icons.smart_toy_outlined,
  ExpenseCategory.icloud => Icons.cloud_outlined,
  ExpenseCategory.googleOne => Icons.cloud_circle_outlined,
  ExpenseCategory.appleMusic => Icons.library_music_outlined,
  ExpenseCategory.disneyPlus => Icons.movie_filter_outlined,
  ExpenseCategory.microsoft365 => Icons.grid_view_outlined,
  ExpenseCategory.subscription => Icons.autorenew_rounded,
};

/// A trip's dates: "10–12 Oct", "30 Sep – 2 Oct", or "12 Oct" for a day trip.
String formatTripDates(DateTime startsOn, DateTime endsOn) {
  final startMonth = monthNames[startsOn.month - 1];
  final endMonth = monthNames[endsOn.month - 1];
  if (startsOn == endsOn) return '${startsOn.day} $startMonth';
  if (startsOn.month == endsOn.month && startsOn.year == endsOn.year) {
    return '${startsOn.day}–${endsOn.day} $endMonth';
  }
  return '${startsOn.day} $startMonth – ${endsOn.day} $endMonth';
}

/// A category's colour pair for its icon tile: [background] wash and
/// [foreground] icon. Subscriptions share one hue — the icon tells them
/// apart.
({Color background, Color foreground}) categoryTone(ExpenseCategory category) => switch (category) {
  ExpenseCategory.food => (background: AppColors.accent100, foreground: AppColors.accent700),
  ExpenseCategory.drinks => (
    background: AppColors.categoryPlumBg,
    foreground: AppColors.categoryPlum,
  ),
  ExpenseCategory.shopping => (
    background: AppColors.categoryRoseBg,
    foreground: AppColors.categoryRose,
  ),
  ExpenseCategory.transport => (
    background: AppColors.categoryBlueBg,
    foreground: AppColors.categoryBlue,
  ),
  ExpenseCategory.stay => (background: AppColors.accent2_100, foreground: AppColors.accent2_700),
  ExpenseCategory.tickets => (
    background: AppColors.categoryGoldBg,
    foreground: AppColors.categoryGold,
  ),
  ExpenseCategory.other => (background: AppColors.neutral200, foreground: AppColors.neutral700),
  _ when category.isSubscription => (
    background: AppColors.categoryTealBg,
    foreground: AppColors.categoryTeal,
  ),
  _ => (background: AppColors.neutral200, foreground: AppColors.neutral700),
};

/// A percent or shares split's weight (hundredths) as shown: "40%",
/// "33.33%", "1 share", "2.5 shares".
String weightLabel(ExpenseSplitMode mode, int hundredths) {
  final number = moneyInput(hundredths);
  return switch (mode) {
    ExpenseSplitMode.percent => '$number%',
    _ => '$number ${hundredths == 100 ? 'share' : 'shares'}',
  };
}
