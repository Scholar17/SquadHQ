import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/edge_fade.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/expense.dart';
import '../active_group.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import '../widgets/expense_sheet.dart';
import '../../domain/entities/squad_ledger.dart';
import '../widgets/squad_widgets.dart';
import '../widgets/trip_actions.dart';
import '../widgets/monthly_card.dart';
import '../widgets/trip_card.dart';

/// A squad's Expenses tab, in three: the squad's own expenses; every
/// trip's (each under its trip, with "Add trip expense"); and monthly
/// expenses (subscriptions charged each month). Newest first, with
/// category filters and search.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key, required this.user});

  final AppUser user;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> with SingleTickerProviderStateMixin {
  ExpenseCategory? _category;
  bool _searching = false;
  final _search = TextEditingController();

  /// Expenses · Trips · Monthly. A category picked on one doesn't carry over.
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging && _category != null) setState(() => _category = null);
    });

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _tabs.dispose();
    super.dispose();
  }

  bool _matches(Expense expense) {
    final query = _search.text.trim().toLowerCase();
    return (_category == null || expense.category == _category) &&
        (query.isEmpty || expense.title.toLowerCase().contains(query));
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
            if (squad == null || ledger == null) return SquadLoadingView(state: state);
            void addExpense() => showExpenseSheet(context, teamId: squad.id, me: me);
            void addMonthly() => showExpenseSheet(context, teamId: squad.id, me: me, monthly: true);
            void addTrip() {
              if (canAddTripExpense(ledger, me)) {
                addTripExpense(context, teamId: squad.id, ledger: ledger, me: me);
                return;
              }
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('No trip is open — an admin starts one.')),
                );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
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
                          backgroundColor: AppColors.card,
                          side: BorderSide(color: AppColors.text.withValues(alpha: 0.1)),
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Adds to whichever list is showing.
                      FilledButton(
                        onPressed: () => switch (_tabs.index) {
                          0 => addExpense(),
                          1 => addTrip(),
                          _ => addMonthly(),
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentFill,
                          minimumSize: const Size(0, 40),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          '+ Add',
                          style: AppTextStyles.title(size: 13, color: AppColors.onDark),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: TextField(
                      controller: _search,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by title',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.pill,
                          borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.14)),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.lg),
                    child: TabBar(
                      controller: _tabs,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: ShapeDecoration(
                        color: AppColors.card,
                        shape: StadiumBorder(),
                      ),
                      labelColor: AppColors.text,
                      unselectedLabelColor: squadMuted,
                      labelStyle: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                      tabs: const [
                        Tab(height: 36, text: 'Expenses'),
                        Tab(height: 36, text: 'Trips'),
                        Tab(height: 36, text: 'Monthly'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _squadList(context, ledger, me, addExpense),
                      _tripList(context, ledger, me, addTrip),
                      _monthlyList(context, ledger, me, squad.id, addMonthly),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _categoryChips(Iterable<Expense> expenses) {
    final categories = {for (final expense in expenses) expense.category};
    if (categories.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 36,
        child: EdgeFade(
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
      ),
    );
  }

  Widget _noMatch(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.body(size: 14, color: squadMuted),
    ),
  );

  /// The squad's own, grouped by month.
  Widget _squadList(BuildContext context, SquadLedger ledger, String me, VoidCallback add) {
    final shown = ledger.expenses.where(_matches).toList();
    final months = <String, List<Expense>>{};
    for (final expense in shown) {
      months.putIfAbsent(formatMonthLabel(expense.spentAt), () => []).add(expense);
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => refreshSquad(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          _categoryChips(ledger.expenses),
          if (ledger.expenses.isEmpty)
            _Empty(onAdd: add)
          else if (shown.isEmpty)
            _noMatch('No expenses match.'),
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
            SeeMoreList(
              previewCount: 5,
              children: [
                for (final expense in expenses)
                  ExpenseRow(
                    expense: expense,
                    ledger: ledger,
                    me: me,
                    onTap: () => context.push(AppRoutes.expenseDetail(expense.id)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Every trip's, each under its trip card (newest trip first).
  Widget _tripList(BuildContext context, SquadLedger ledger, String me, VoidCallback add) {
    final filtering = _category != null || _search.text.trim().isNotEmpty;
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => refreshSquad(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          if (canAddTripExpense(ledger, me)) ...[
            OutlinedButton.icon(
              onPressed: add,
              icon: const Icon(Icons.luggage_outlined, size: 18),
              label: Text(
                'Add trip expense',
                style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: oweColor,
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(color: oweColor),
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _categoryChips(ledger.tripExpenses),
          if (ledger.trips.isEmpty)
            _noMatch(
              'No trips yet. Going away together? An admin starts one with Add trip expense.',
            )
          else if (filtering && !ledger.tripExpenses.any(_matches))
            _noMatch('No trip expenses match.'),
          for (final trip in ledger.trips)
            if (ledger.forTrip(trip.id).expenses.where(_matches).toList() case final expenses
                when expenses.isNotEmpty || !filtering) ...[
              const SizedBox(height: 12),
              TripCard(trip: trip, ledger: ledger, me: me),
              const SizedBox(height: 8),
              if (expenses.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'No expenses on this trip yet.',
                    style: AppTextStyles.body(size: 12.5, color: squadMuted),
                  ),
                )
              else
                SeeMoreList(
                  children: [
                    for (final expense in expenses)
                      ExpenseRow(
                        expense: expense,
                        ledger: ledger,
                        me: me,
                        showTrip: false,
                        onTap: () => context.push(AppRoutes.expenseDetail(expense.id)),
                      ),
                  ],
                ),
            ],
        ],
      ),
    );
  }

  /// Monthly expenses: each subscription, when it's charged next, and
  /// what you pay; tap one to change, pause or stop it.
  Widget _monthlyList(
    BuildContext context,
    SquadLedger ledger,
    String me,
    String teamId,
    VoidCallback add,
  ) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => refreshSquad(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          OutlinedButton.icon(
            onPressed: add,
            icon: const Icon(Icons.autorenew_rounded, size: 18),
            label: Text(
              'Add monthly expense',
              style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: oweColor,
              minimumSize: const Size.fromHeight(46),
              side: BorderSide(color: oweColor),
              shape: const StadiumBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (ledger.recurring.isEmpty)
            _noMatch(
              'Share a YouTube or Canva family plan? Add it once — each month the squad '
              'gets the charge, and everyone in it is reminded to pay.',
            )
          else
            SeeMoreList(
              previewCount: 5,
              children: [
                for (final rec in ledger.recurring)
                  MonthlyCard(recurring: rec, ledger: ledger, me: me, teamId: teamId),
              ],
            ),
        ],
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
          Icon(Icons.receipt_long_outlined, size: 40, color: squadMuted),
          const SizedBox(height: 12),
          Text('No expenses yet', style: AppTextStyles.title(size: 18)),
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
