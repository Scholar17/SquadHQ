import 'package:equatable/equatable.dart';

import 'expense.dart';

/// A monthly expense — a shared subscription like a YouTube or Canva
/// family plan (supabase/sql/036_monthly_expenses.sql). On [chargeDay]
/// each month the squad gets that month's expense automatically.
class RecurringExpense extends Equatable {
  const RecurringExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.amountCents,
    required this.payerId,
    required this.splitMode,
    required this.shares,
    required this.chargeDay,
    required this.startsOn,
    required this.createdBy,
    this.note,
    this.pausedAt,
    this.lastMonth,
    this.categoryLabel,
  });

  /// [chargeDay] for "the last day of the month", whatever its length.
  static const lastDay = 31;

  final String id;
  final String title;
  final ExpenseCategory category;
  final int amountCents;

  /// Who pays the provider each month.
  final String payerId;
  final ExpenseSplitMode splitMode;

  /// What each person owes each month, summing to [amountCents].
  final Map<String, int> shares;

  /// 1–28, or [lastDay].
  final int chargeDay;

  /// The first month charged (its 1st).
  final DateTime startsOn;
  final String createdBy;
  final String? note;
  final DateTime? pausedAt;

  /// The latest month charged (its 1st); null before the first.
  final DateTime? lastMonth;

  /// What "Other" is ("Amazon Prime"), if named (040).
  final String? categoryLabel;

  bool get isPaused => pausedAt != null;

  int shareOf(String profileId) => shares[profileId] ?? 0;

  /// An admin, whoever set it up, or its payer.
  bool canManage(String profileId, {required bool isAdmin}) =>
      isAdmin || profileId == createdBy || profileId == payerId;

  /// The day it's charged in [month] (any day in it).
  DateTime chargeDateIn(DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, chargeDay < daysInMonth ? chargeDay : daysInMonth);
  }

  /// The next charge on or after [today]: this month's if it hasn't been
  /// charged, else next month's — never before [startsOn]. Null if paused.
  DateTime? nextCharge(DateTime today) {
    if (isPaused) return null;
    var month = DateTime(today.year, today.month);
    if (month.isBefore(startsOn)) month = startsOn;
    final charged = lastMonth;
    if (charged != null && !month.isAfter(charged)) {
      month = DateTime(charged.year, charged.month + 1);
    }
    return chargeDateIn(month);
  }

  @override
  List<Object?> get props => [
    id,
    title,
    category,
    amountCents,
    payerId,
    splitMode,
    shares,
    chargeDay,
    startsOn,
    createdBy,
    note,
    pausedAt,
    lastMonth,
    categoryLabel,
  ];
}
