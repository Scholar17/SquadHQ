import 'package:equatable/equatable.dart';

import 'personal_expense.dart';

/// How the My spending page filters: one day, month or year (stepped back
/// and forward), or a range of days you pick.
enum ReportPeriod {
  day('Day'),
  month('Month'),
  year('Year'),
  range('Range');

  const ReportPeriod(this.label);

  final String label;
}

/// A span of days, [start] inclusive to [end] exclusive, in local time.
class ReportWindow extends Equatable {
  const ReportWindow(this.start, this.end);

  /// The day, month or year holding [anchor].
  factory ReportWindow.around(ReportPeriod period, DateTime anchor) => switch (period) {
    ReportPeriod.day => ReportWindow(
      DateTime(anchor.year, anchor.month, anchor.day),
      DateTime(anchor.year, anchor.month, anchor.day + 1),
    ),
    ReportPeriod.month || ReportPeriod.range => ReportWindow(
      DateTime(anchor.year, anchor.month),
      DateTime(anchor.year, anchor.month + 1),
    ),
    ReportPeriod.year => ReportWindow(DateTime(anchor.year), DateTime(anchor.year + 1)),
  };

  /// From the day of [first] through the whole day of [last].
  factory ReportWindow.days(DateTime first, DateTime last) => ReportWindow(
    DateTime(first.year, first.month, first.day),
    DateTime(last.year, last.month, last.day + 1),
  );

  final DateTime start;
  final DateTime end;

  bool contains(DateTime at) {
    final local = at.toLocal();
    return !local.isBefore(start) && local.isBefore(end);
  }

  @override
  List<Object?> get props => [start, end];
}

/// One category's share of a report.
class CategoryTotal extends Equatable {
  const CategoryTotal({required this.key, required this.cents, required this.count});

  /// A [PersonalExpense.categoryKey].
  final String key;
  final int cents;
  final int count;

  @override
  List<Object?> get props => [key, cents, count];
}

/// One month's total in a year's report.
class MonthTotal extends Equatable {
  const MonthTotal({required this.month, required this.cents});

  /// The month's 1st.
  final DateTime month;
  final int cents;

  @override
  List<Object?> get props => [month, cents];
}

/// What you spent in a [ReportWindow]: the total, by category (biggest
/// first), by month, and the expenses themselves (newest first).
class SpendingReport extends Equatable {
  const SpendingReport._({
    required this.totalCents,
    required this.expenses,
    required this.byCategory,
    required this.byMonth,
  });

  factory SpendingReport.of(List<PersonalExpense> all, ReportWindow window) {
    final expenses = [
      for (final expense in all)
        if (window.contains(expense.spentAt)) expense,
    ]..sort((a, b) => b.spentAt.compareTo(a.spentAt));
    final cents = <String, int>{};
    final counts = <String, int>{};
    final months = <DateTime, int>{};
    for (final expense in expenses) {
      final key = expense.categoryKey;
      cents[key] = (cents[key] ?? 0) + expense.amountCents;
      counts[key] = (counts[key] ?? 0) + 1;
      final local = expense.spentAt.toLocal();
      final month = DateTime(local.year, local.month);
      months[month] = (months[month] ?? 0) + expense.amountCents;
    }
    return SpendingReport._(
      totalCents: cents.values.fold(0, (a, b) => a + b),
      expenses: expenses,
      byCategory: [
        for (final key in cents.keys) CategoryTotal(key: key, cents: cents[key]!, count: counts[key]!),
      ]..sort((a, b) => b.cents.compareTo(a.cents)),
      byMonth: [
        for (final MapEntry(:key, :value) in months.entries) MonthTotal(month: key, cents: value),
      ]..sort((a, b) => a.month.compareTo(b.month)),
    );
  }

  final int totalCents;
  final List<PersonalExpense> expenses;
  final List<CategoryTotal> byCategory;
  final List<MonthTotal> byMonth;

  @override
  List<Object?> get props => [totalCents, expenses, byCategory, byMonth];
}
