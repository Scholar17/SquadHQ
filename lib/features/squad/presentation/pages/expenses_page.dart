import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/expense.dart';
import '../active_group.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/squad_widgets.dart';

/// A squad's Expenses tab: every expense, newest first, grouped by month,
/// with category filters and search.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key, required this.user});

  final AppUser user;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  ExpenseCategory? _category;
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final squad = watchActiveGroup(context);
    final me = widget.user.id;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<SquadLedgerBloc, SquadLedgerState>(
          builder: (context, state) {
            final ledger = state.ledger;
            if (squad == null || ledger == null) {
              return const Center(child: CircularProgressIndicator(color: AppColors.accent));
            }
            final query = _search.text.trim().toLowerCase();
            final categories = {for (final expense in ledger.expenses) expense.category};
            final shown = [
              for (final expense in ledger.expenses)
                if ((_category == null || expense.category == _category) &&
                    (query.isEmpty || expense.title.toLowerCase().contains(query)))
                  expense,
            ];
            final months = <String, List<Expense>>{};
            for (final expense in shown) {
              months.putIfAbsent(formatMonthLabel(expense.spentAt), () => []).add(expense);
            }
            return RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => refreshSquad(context),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Expenses', style: AppTextStyles.heading(size: 24))),
                      IconButton(
                        tooltip: _searching ? 'Close search' : 'Search expenses',
                        onPressed: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) _search.clear();
                        }),
                        icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.neutral100,
                          side: BorderSide(color: AppColors.text.withValues(alpha: 0.1)),
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => showExpenseSheet(context, teamId: squad.id, me: me),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent700,
                          minimumSize: const Size(0, 40),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          '+ Add',
                          style: AppTextStyles.heading(size: 13, color: AppColors.neutral100),
                        ),
                      ),
                    ],
                  ),
                  if (_searching) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by title',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppColors.neutral100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.14)),
                        ),
                      ),
                    ),
                  ],
                  if (categories.length > 1) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          SquadChoiceChip(
                            label: 'All',
                            selected: _category == null,
                            onTap: () => setState(() => _category = null),
                          ),
                          for (final category in ExpenseCategory.values)
                            if (categories.contains(category)) ...[
                              const SizedBox(width: 8),
                              SquadChoiceChip(
                                label: category.label,
                                selected: _category == category,
                                onTap: () => setState(() => _category = category),
                              ),
                            ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (ledger.expenses.isEmpty)
                    _Empty(
                      onAdd: () => showExpenseSheet(context, teamId: squad.id, me: me),
                    )
                  else if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No expenses match.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(size: 14, color: squadMuted),
                      ),
                    ),
                  for (final MapEntry(key: month, value: expenses) in months.entries) ...[
                    const SizedBox(height: 12),
                    SquadSectionLabel(
                      month,
                      // Treats count too: the month's total spending.
                      trailing: formatMoney(
                        expenses.fold(0, (sum, e) => sum + e.amountCents),
                        ledger.currency,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final expense in expenses) ...[
                      ExpenseRow(
                        expense: expense,
                        ledger: ledger,
                        me: me,
                        onTap: () => context.push(AppRoutes.expenseDetail(expense.id)),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 40, color: squadMuted),
          const SizedBox(height: 12),
          Text('No expenses yet', style: AppTextStyles.heading(size: 18)),
          const SizedBox(height: 6),
          Text(
            'Add the first one after your next meal out.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 13, color: squadMuted),
          ),
          const SizedBox(height: 16),
          SquadPrimaryButton(label: '+ Add expense', onPressed: onAdd),
        ],
      ),
    );
  }
}
