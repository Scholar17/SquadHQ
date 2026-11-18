import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../squad/presentation/squad_formatting.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../../team_membership/domain/entities/team.dart' show GroupCurrency;
import '../../domain/entities/personal_expense.dart';
import '../../domain/entities/spending_report.dart';
import '../cubit/personal_spending_cubit.dart';
import '../personal_formatting.dart';
import '../widgets/personal_expense_sheet.dart';

/// "My spending": your personal expenses across all squads, filtered by a
/// day, month, year or range of days, with the total, each category's
/// share and (for a year) each month's total.
class MySpendingPage extends StatefulWidget {
  const MySpendingPage({super.key});

  @override
  State<MySpendingPage> createState() => _MySpendingPageState();
}

class _MySpendingPageState extends State<MySpendingPage> {
  final _cubit = sl<PersonalSpendingCubit>();

  ReportPeriod _period = ReportPeriod.month;
  DateTime _anchor = DateTime.now();

  /// The days picked for [ReportPeriod.range].
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _cubit.load();
  }

  ReportWindow get _window => switch ((_period, _range)) {
    (ReportPeriod.range, final range?) => ReportWindow.days(range.start, range.end),
    _ => ReportWindow.around(_period, _anchor),
  };

  /// Steps a day, month or year back (-1) or forward (1).
  void _step(int by) => setState(
    () => _anchor = switch (_period) {
      ReportPeriod.day => DateTime(_anchor.year, _anchor.month, _anchor.day + by),
      ReportPeriod.month || ReportPeriod.range => DateTime(_anchor.year, _anchor.month + by),
      ReportPeriod.year => DateTime(_anchor.year + by),
    },
  );

  bool get _atNow {
    final now = DateTime.now();
    return ReportWindow.around(_period, now) == ReportWindow.around(_period, _anchor);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: _range ?? DateTimeRange(start: DateTime(now.year, now.month), end: now),
    );
    if (picked != null && mounted) {
      setState(() {
        _range = picked;
        _period = ReportPeriod.range;
      });
    }
  }

  Future<void> _manageCategories(PersonalSpending spending) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => BlocProvider.value(value: _cubit, child: const _CategoriesSheet()),
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<PersonalSpendingCubit, PersonalSpendingState>(
        listenWhen: (previous, current) =>
            current.error != null && previous.error != current.error,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.error!))),
        builder: (context, state) {
          final spending = state.spending;
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              backgroundColor: AppColors.bg,
              title: Text('My spending', style: AppTextStyles.heading(size: 20)),
              actions: [
                if (spending != null)
                  PopupMenuButton<Object>(
                    tooltip: 'More',
                    color: AppColors.card,
                    onSelected: (choice) {
                      if (choice case final GroupCurrency currency) _cubit.setCurrency(currency);
                      if (choice == 'categories') _manageCategories(spending);
                    },
                    itemBuilder: (_) => [
                      for (final currency in GroupCurrency.values)
                        CheckedPopupMenuItem<Object>(
                          value: currency,
                          checked: spending.currency == currency,
                          child: Text('${currency.symbol}  ${currency.label}'),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<Object>(
                        value: 'categories',
                        child: Text('Your categories'),
                      ),
                    ],
                  ),
              ],
            ),
            floatingActionButton: spending == null
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => showPersonalExpenseSheet(context),
                    backgroundColor: AppColors.accentFill,
                    foregroundColor: AppColors.onDark,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
            body: spending == null
                ? Center(
                    child: state.loading || state.error == null
                        ? const CircularProgressIndicator()
                        : TextButton(onPressed: _cubit.load, child: const Text('Try again')),
                  )
                : RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: _cubit.load,
                    child: _Report(
                      spending: spending,
                      period: _period,
                      window: _window,
                      atNow: _atNow,
                      onPeriod: (period) {
                        if (period == ReportPeriod.range) {
                          _pickRange();
                        } else {
                          setState(() => _period = period);
                        }
                      },
                      onStep: _step,
                      onPickRange: _pickRange,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({
    required this.spending,
    required this.period,
    required this.window,
    required this.atNow,
    required this.onPeriod,
    required this.onStep,
    required this.onPickRange,
  });

  final PersonalSpending spending;
  final ReportPeriod period;
  final ReportWindow window;

  /// Showing this day, month or year: no stepping forward past it.
  final bool atNow;
  final ValueChanged<ReportPeriod> onPeriod;
  final ValueChanged<int> onStep;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final report = SpendingReport.of(spending.expenses, window);
    final currency = spending.currency;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in ReportPeriod.values)
              SquadChoiceChip(
                label: option.label,
                selected: option == period,
                onTap: () => onPeriod(option),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (period != ReportPeriod.range)
              IconButton(
                onPressed: () => onStep(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous',
              ),
            Expanded(
              child: period == ReportPeriod.range
                  ? TextButton.icon(
                      onPressed: onPickRange,
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      label: Text(
                        formatWindow(period, window),
                        style: AppTextStyles.title(size: 16),
                      ),
                    )
                  : Text(
                      formatWindow(period, window),
                      key: const ValueKey('report-window'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title(size: 16),
                    ),
            ),
            if (period != ReportPeriod.range)
              IconButton(
                onPressed: atNow ? null : () => onStep(1),
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next',
              ),
          ],
        ),
        const SizedBox(height: 8),
        SquadCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOU SPENT', style: AppTextStyles.label(color: squadMuted)),
              const SizedBox(height: 4),
              Text(
                formatMoney(report.totalCents, currency),
                key: const ValueKey('report-total'),
                style: AppTextStyles.heading(size: 34),
              ),
              Text(
                switch (report.expenses.length) {
                  0 => 'Nothing yet',
                  1 => '1 expense',
                  final n => '$n expenses',
                },
                style: AppTextStyles.body(size: 12.5, color: squadMuted),
              ),
            ],
          ),
        ),
        if (report.expenses.isEmpty) ...[
          const SizedBox(height: 24),
          Text(
            spending.expenses.isEmpty
                ? 'Track what you spend on yourself. Only you can see it.'
                : 'No personal expenses in this ${period == ReportPeriod.range ? 'range' : period.label.toLowerCase()}.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 13, color: squadMuted),
          ),
        ],
        if (period == ReportPeriod.year && report.byMonth.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SquadSectionLabel('BY MONTH'),
          const SizedBox(height: 6),
          _Bars(
            rows: [
              for (final month in report.byMonth)
                (label: monthShort(month.month), sub: null, cents: month.cents, icon: null),
            ],
            currency: currency,
          ),
        ],
        if (report.byCategory.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SquadSectionLabel('BY CATEGORY'),
          const SizedBox(height: 6),
          _Bars(
            rows: [
              for (final category in report.byCategory)
                (
                  label: spending.labelOf(category.key),
                  sub: category.count == 1 ? '1 expense' : '${category.count} expenses',
                  cents: category.cents,
                  icon: personalCategoryIcon(category.key),
                ),
            ],
            currency: currency,
            total: report.totalCents,
          ),
        ],
        if (report.expenses.isNotEmpty) ...[
          const SizedBox(height: 18),
          SquadSectionLabel('EXPENSES', trailing: '${report.expenses.length}'),
          const SizedBox(height: 6),
          for (final expense in report.expenses) ...[
            SquadCard(
              onTap: () => showPersonalExpenseSheet(context, editing: expense),
              child: Row(
                children: [
                  Icon(personalCategoryIcon(expense.categoryKey), color: squadMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700),
                        ),
                        Text(
                          [
                            spending.labelOf(expense.categoryKey),
                            formatDayLabel(expense.spentAt),
                            if (expense.receiptPath != null) 'receipt',
                          ].join(' · '),
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(size: 12, color: squadMuted),
                        ),
                        if (expense.note case final note?)
                          Text(
                            note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(size: 12, color: squadMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatMoney(expense.amountCents, currency),
                    style: AppTextStyles.body(size: 15, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

/// Amounts as rows with a bar against the biggest; with [total], each
/// row's % of it too.
class _Bars extends StatelessWidget {
  const _Bars({required this.rows, required this.currency, this.total});

  final List<({String label, String? sub, int cents, IconData? icon})> rows;
  final GroupCurrency currency;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final biggest = rows.fold(0, (a, row) => row.cents > a ? row.cents : a);
    return SquadCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (row.icon case final icon?) ...[
                        Icon(icon, size: 18, color: squadMuted),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          row.label,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                        ),
                      ),
                      if (row.sub case final sub?)
                        Text(sub, style: AppTextStyles.body(size: 11.5, color: squadMuted)),
                      const SizedBox(width: 10),
                      Text(
                        switch (total) {
                          final total? when total > 0 =>
                            '${formatMoney(row.cents, currency)}  ${(row.cents * 100 / total).round()}%',
                          _ => formatMoney(row.cents, currency),
                        },
                        style: AppTextStyles.body(size: 13.5, weight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: biggest == 0 ? 0 : row.cents / biggest,
                      minHeight: 6,
                      backgroundColor: AppColors.surface,
                      color: AppColors.accentFill,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Your categories": delete one (its expenses move to Other).
class _CategoriesSheet extends StatelessWidget {
  const _CategoriesSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersonalSpendingCubit, PersonalSpendingState>(
      builder: (context, state) {
        final categories = state.spending?.categories ?? const <CustomCategory>[];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Text('Your categories', style: AppTextStyles.title(size: 18)),
              const SizedBox(height: 4),
              Text(
                'Add one from “New category” when you add an expense. '
                'Deleting one moves its expenses to Other.',
                style: AppTextStyles.body(size: 12.5, color: squadMuted),
              ),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('None yet.', style: AppTextStyles.body(size: 13)),
                ),
              for (final category in categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.label_outline_rounded),
                  title: Text(category.name),
                  trailing: IconButton(
                    onPressed: state.saving
                        ? null
                        : () => context.read<PersonalSpendingCubit>().deleteCategory(category.id),
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Delete ${category.name}',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
