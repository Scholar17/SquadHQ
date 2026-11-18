import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/personal/domain/entities/personal_expense.dart';
import 'package:squad_hq/features/personal/domain/entities/spending_report.dart';
import 'package:squad_hq/features/personal/presentation/personal_formatting.dart';

PersonalExpense spent(
  String id,
  int cents,
  DateTime at, {
  PersonalCategory category = PersonalCategory.food,
  String? customId,
}) => PersonalExpense(
  id: id,
  title: id,
  amountCents: cents,
  spentAt: at,
  category: customId == null ? category : PersonalCategory.custom,
  customCategoryId: customId,
);

void main() {
  final all = [
    spent('lunch', 12000, DateTime(2026, 11, 18, 12)),
    spent('taxi', 8000, DateTime(2026, 11, 18, 9), category: PersonalCategory.transport),
    spent('coffee', 6000, DateTime(2026, 11, 2), customId: 'cat-1'),
    spent('boots', 250000, DateTime(2026, 3, 5), category: PersonalCategory.sports),
    spent('old', 1000, DateTime(2025, 12, 31, 23, 59)),
  ];

  test('A day: only that day, newest first', () {
    final report = SpendingReport.of(all, ReportWindow.around(ReportPeriod.day, DateTime(2026, 11, 18)));
    expect(report.totalCents, 20000);
    expect(report.expenses.map((e) => e.id), ['lunch', 'taxi']);
  });

  test('A month: total and categories, biggest first', () {
    final report = SpendingReport.of(all, ReportWindow.around(ReportPeriod.month, DateTime(2026, 11, 5)));
    expect(report.totalCents, 26000);
    expect(report.byCategory.map((c) => (c.key, c.cents)), [
      ('food', 12000),
      ('transport', 8000),
      ('custom:cat-1', 6000),
    ]);
  });

  test('A year: each month’s total, in order; the year before is out', () {
    final report = SpendingReport.of(all, ReportWindow.around(ReportPeriod.year, DateTime(2026, 6)));
    expect(report.totalCents, 276000);
    expect(report.byMonth.map((m) => (m.month, m.cents)), [
      (DateTime(2026, 3), 250000),
      (DateTime(2026, 11), 26000),
    ]);
  });

  test('A range includes the whole last day', () {
    final report = SpendingReport.of(
      all,
      ReportWindow.days(DateTime(2025, 12, 31), DateTime(2026, 3, 5)),
    );
    expect(report.expenses.map((e) => e.id), ['boots', 'old']);
  });

  test('A deleted category’s expenses count as Other', () {
    final orphan = spent('gym', 5000, DateTime(2026, 11, 1), category: PersonalCategory.custom);
    expect(orphan.categoryKey, 'other');
    final spending = PersonalSpending(
      expenses: const [],
      categories: const [CustomCategory(id: 'cat-1', name: 'Coffee')],
      currency: PersonalSpending.empty.currency,
    );
    expect(spending.labelOf('custom:cat-1'), 'Coffee');
    expect(spending.labelOf('custom:gone'), 'Other');
    expect(spending.labelOf('transport'), 'Transport');
  });

  test('Window labels', () {
    expect(
      formatWindow(ReportPeriod.month, ReportWindow.around(ReportPeriod.month, DateTime(2026, 11, 18))),
      'November 2026',
    );
    expect(
      formatWindow(ReportPeriod.year, ReportWindow.around(ReportPeriod.year, DateTime(2026, 11, 18))),
      '2026',
    );
    expect(
      formatWindow(ReportPeriod.range, ReportWindow.days(DateTime(2026, 11, 1), DateTime(2026, 11, 18))),
      '1 Nov – 18 Nov 2026',
    );
  });
}
