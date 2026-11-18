import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/skeletons.dart';
import '../../../squad/presentation/widgets/sheet_parts.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../../team_membership/domain/entities/team.dart' show GroupCurrency;
import '../../domain/entities/personal_expense.dart';
import '../../domain/entities/spending_report.dart';
import '../cubit/personal_spending_cubit.dart';
import '../personal_formatting.dart';
import '../widgets/personal_expense_sheet.dart';
import '../widgets/spending_widgets.dart';

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
                      if (choice == 'categories') showYourCategoriesSheet(context, _cubit);
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
                ? state.loading || state.error == null
                      ? const SkeletonList(item: ExpenseRowSkeleton(), count: 6, spacing: 8)
                      : _LoadFailed(onRetry: _cubit.load)
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
    final label = formatWindow(period, window);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      children: [
        SegmentedTabs<ReportPeriod>(
          options: ReportPeriod.values,
          selected: period,
          label: (option) => option.label,
          onChanged: onPeriod,
          expand: true,
        ),
        const SizedBox(height: 6),
        _WindowStepper(
          period: period,
          label: label,
          atNow: atNow,
          onStep: onStep,
          onPickRange: onPickRange,
        ),
        const SizedBox(height: 6),
        SpendingTotalHero(
          totalCents: report.totalCents,
          count: report.expenses.length,
          currency: currency,
        ),
        if (report.expenses.isEmpty) ...[
          const SizedBox(height: 16),
          SpendingEmpty(
            text: spending.expenses.isEmpty
                ? 'Track what you spend on yourself — tap Add. Only you can see it.'
                : 'No personal expenses in this ${period == ReportPeriod.range ? 'range' : period.label.toLowerCase()}.',
          ),
        ],
        if (period == ReportPeriod.year && report.byMonth.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SquadSectionLabel('BY MONTH'),
          const SizedBox(height: 8),
          SpendingBars(
            rows: [
              for (final month in report.byMonth)
                (label: monthShort(month.month), sub: null, cents: month.cents, categoryKey: null),
            ],
            currency: currency,
          ),
        ],
        if (report.byCategory.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SquadSectionLabel('BY CATEGORY'),
          const SizedBox(height: 8),
          SpendingBars(
            rows: [
              for (final category in report.byCategory)
                (
                  label: spending.labelOf(category.key),
                  sub: category.count == 1 ? '1 expense' : '${category.count} expenses',
                  cents: category.cents,
                  categoryKey: category.key,
                ),
            ],
            currency: currency,
            total: report.totalCents,
          ),
        ],
        if (report.expenses.isNotEmpty) ...[
          const SizedBox(height: 20),
          SquadSectionLabel('EXPENSES', trailing: '${report.expenses.length}'),
          const SizedBox(height: 8),
          SeeMoreList(
            previewCount: 10,
            children: [
              for (final expense in report.expenses)
                PersonalExpenseTile(expense: expense, spending: spending),
            ],
          ),
        ],
      ],
    );
  }
}

/// ‹ November 2026 › — or, for a range, the days picked (tap to change).
class _WindowStepper extends StatelessWidget {
  const _WindowStepper({
    required this.period,
    required this.label,
    required this.atNow,
    required this.onStep,
    required this.onPickRange,
  });

  final ReportPeriod period;
  final String label;
  final bool atNow;
  final ValueChanged<int> onStep;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    if (period == ReportPeriod.range) {
      return Center(
        child: TextButton.icon(
          onPressed: onPickRange,
          icon: const Icon(Icons.date_range_outlined, size: 18),
          label: Text(label, style: AppTextStyles.title(size: 16)),
          style: TextButton.styleFrom(foregroundColor: AppColors.text, minimumSize: const Size(0, 48)),
        ),
      );
    }
    return Row(
      children: [
        IconButton(
          onPressed: () => onStep(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous',
        ),
        Expanded(
          child: Text(
            label,
            key: const ValueKey('report-window'),
            textAlign: TextAlign.center,
            style: AppTextStyles.title(size: 16),
          ),
        ),
        IconButton(
          onPressed: atNow ? null : () => onStep(1),
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next',
        ),
      ],
    );
  }
}

/// Spending didn't load: the reason and Retry.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: squadMuted),
            const SizedBox(height: 12),
            Text(
              "Couldn't load your spending",
              textAlign: TextAlign.center,
              style: AppTextStyles.title(size: 18),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                minimumSize: const Size(0, 44),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
