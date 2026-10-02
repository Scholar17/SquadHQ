import 'package:flutter/material.dart';

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

/// Minor units back to editable text: "1150" or "287.5".
String moneyInput(int cents) {
  if (cents % 100 == 0) return (cents ~/ 100).toString();
  return (cents / 100).toStringAsFixed(2);
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
};
