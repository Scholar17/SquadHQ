import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../notifications/presentation/widgets/other_groups_activity.dart';
import '../../../team/domain/entities/team_snapshot.dart' show TeamInfo;
import '../../../team/presentation/widgets/team_header.dart';
import '../../../team_membership/domain/entities/team.dart';
import '../../../team_membership/presentation/widgets/team_switcher_sheet.dart';
import '../../domain/entities/squad_ledger.dart';
import '../active_group.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import '../widgets/confirm_payment_sheet.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/payment_extras.dart';
import '../widgets/remind_button.dart';
import '../widgets/squad_widgets.dart';
import '../widgets/trip_actions.dart';
import '../widgets/trip_card.dart';

/// A squad's Home tab: your balance up front, payments waiting for you to
/// confirm, and the last few expenses.
class SquadHomePage extends StatelessWidget {
  const SquadHomePage({super.key, required this.user});

  final AppUser user;

  static const previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final squad = watchActiveGroup(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<SquadLedgerBloc, SquadLedgerState>(
          builder: (context, state) {
            final ledger = state.ledger;
            if (squad == null || ledger == null) return SquadLoadingView(state: state);
            final me = user.id;
            return RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => _refresh(context),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  TeamHeader(
                    team: TeamInfo(
                      name: squad.name,
                      meta:
                          'Squad · ${ledger.members.length} '
                          '${ledger.members.length == 1 ? 'member' : 'members'}',
                      initials: groupInitials(squad.name),
                      alertCount: context.watch<NotificationBloc>().state.unreadCount,
                    ),
                    profileInitials: user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                    onTeamTap: () => showTeamSwitcherSheet(context),
                    onBellTap: () => context.push(
                      AppRoutes.notifications,
                      extra: NotificationsArgs(userId: me),
                    ),
                    onProfileTap: () => context.push(AppRoutes.profile, extra: user),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const OtherGroupsActivity(padding: EdgeInsets.only(bottom: 16)),
                        _BalanceHero(
                          ledger: ledger,
                          me: me,
                          onSettle: () => context.go(AppRoutes.wallet),
                          onAdd: () => showExpenseSheet(context, teamId: squad.id, me: me),
                          onAddTrip: canAddTripExpense(ledger, me)
                              ? () => addTripExpense(
                                  context,
                                  teamId: squad.id,
                                  ledger: ledger,
                                  me: me,
                                )
                              : null,
                          onAddMonthly: () =>
                              showExpenseSheet(context, teamId: squad.id, me: me, monthly: true),
                        ),
                        const SizedBox(height: 12),
                        // At most two of each up front; the rest fold away.
                        SeeMoreList(
                          previewCount: 2,
                          spacing: 12,
                          children: [
                            for (final settlement in ledger.awaitingConfirmationBy(me))
                              CheckPaymentCard(
                                title:
                                    '${ledger.nameOf(settlement.fromId)} says they paid you '
                                    '${formatMoney(settlement.amountCents, ledger.currency)}'
                                    '${partialLabel(ledger, settlement)}',
                                onTap: () =>
                                    showConfirmPaymentSheet(context, settlement: settlement),
                              ),
                            // A trip's payments too — settled apart, confirmed here.
                            for (final settlement in ledger.tripPaymentsAwaiting(me))
                              CheckPaymentCard(
                                title:
                                    '${ledger.nameOf(settlement.fromId)} says they paid you '
                                    '${formatMoney(settlement.amountCents, ledger.currency)}'
                                    '${partialLabel(ledger, settlement)}'
                                    '${switch (ledger.trip(settlement.tripId!)) {
                                      final trip? => ' for ${trip.name}',
                                      null => '',
                                    }}',
                                onTap: () =>
                                    showConfirmPaymentSheet(context, settlement: settlement),
                              ),
                          ],
                        ),
                        // Payments you sent that the receiver hasn't confirmed.
                        SeeMoreList(
                          previewCount: 2,
                          spacing: 12,
                          children: [
                            for (final settlement in ledger.pendingFrom(me))
                              _WaitingBanner(
                                text:
                                    'You paid ${ledger.nameOf(settlement.toId)} '
                                    '${formatMoney(settlement.amountCents, ledger.currency)} · '
                                    'waiting for them to confirm',
                                reminder: ConfirmReminderButton(
                                  settlementId: settlement.id,
                                  receiverName: ledger.nameOf(settlement.toId),
                                  remindedToday: settlement.nudgedToday(),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _Trips(squad: squad, ledger: ledger, me: me),
                        _RecentExpenses(squad: squad, ledger: ledger, me: me),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Future<void> _refresh(BuildContext context) => refreshSquad(context);
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.ledger,
    required this.me,
    required this.onSettle,
    required this.onAdd,
    required this.onAddTrip,
    required this.onAddMonthly,
  });

  final SquadLedger ledger;
  final String me;
  final VoidCallback onSettle;
  final VoidCallback onAdd;

  /// "Add trip expense"; null hides it (no open trip, and not an admin
  /// who could start one).
  final VoidCallback? onAddTrip;

  /// "Add monthly expense": a subscription charged each month.
  final VoidCallback onAddMonthly;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final balance = ledger.balanceOf(me);
    // Same open debts as Settle: payments still waiting count as paid.
    final debts = ledger.openDebts;
    int total(Iterable<Debt> list) => list.fold(0, (sum, debt) => sum + debt.amountCents);
    final payCents = total(debts.where((debt) => debt.fromId == me));
    final getCents = total(debts.where((debt) => debt.toId == me));
    final pending = ledger.pendingFrom(me);
    final headline = switch (balance) {
      < 0 => 'Overall you owe',
      > 0 => "Overall you're owed",
      _ => "You're all square",
    };
    final detail = [
      if (payCents > 0) 'You pay ${formatMoney(payCents, currency)}',
      if (getCents > 0) 'you get ${formatMoney(getCents, currency)}',
      if (pending.isNotEmpty)
        '${formatMoney(pending.fold(0, (sum, s) => sum + s.amountCents), currency)} '
            'waiting for ${pending.length == 1 ? ledger.nameOf(pending.single.toId) : 'others'} '
            'to confirm',
    ].join(' · ');
    const light = AppColors.onDark;
    return DarkHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR BALANCE', style: AppTextStyles.label(color: AppColors.teamGold)),
          const SizedBox(height: 8),
          Text(
            headline,
            style: AppTextStyles.body(
              size: 13,
              weight: FontWeight.w600,
              color: light.withValues(alpha: 0.85),
            ),
          ),
          Text(
            formatMoney(balance.abs(), currency),
            style: AppTextStyles.heading(size: 40, color: AppColors.teamGold),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(detail, style: AppTextStyles.body(size: 12, color: light.withValues(alpha: 0.85))),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: HeroPillButton(label: 'Settle up', onPressed: onSettle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeroPillButton(
                  label: 'Add expense',
                  icon: Icons.add_rounded,
                  light: false,
                  onPressed: onAdd,
                ),
              ),
            ],
          ),
          // Trip and monthly side by side; monthly alone when no trip's open.
          const SizedBox(height: 10),
          Row(
            children: [
              if (onAddTrip case final onAddTrip?) ...[
                Expanded(
                  child: HeroPillButton(
                    label: 'Trip expense',
                    icon: Icons.luggage_outlined,
                    light: false,
                    onPressed: onAddTrip,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: HeroPillButton(
                  label: onAddTrip == null ? 'Add monthly expense' : 'Monthly expense',
                  icon: Icons.autorenew_rounded,
                  light: false,
                  onPressed: onAddMonthly,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({required this.text, required this.reminder});

  final String text;
  final Widget reminder;

  @override
  Widget build(BuildContext context) {
    // The reminder sits under the text, so the text keeps the full width.
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.schedule_rounded, size: 20, color: oweColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)),
                const SizedBox(height: 8),
                reminder,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The squad's trips — open ones first, then the latest closed — each with
/// where you stand (new ones start from "Add trip expense"). Hidden for
/// non-admins when there are none.
class _Trips extends StatelessWidget {
  const _Trips({required this.squad, required this.ledger, required this.me});

  final Team squad;
  final SquadLedger ledger;
  final String me;

  static const _closedShown = 2;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ledger.member(me)?.isAdmin ?? false;
    final open = ledger.trips.where((t) => !t.isClosed).toList();
    final closed = ledger.trips.where((t) => t.isClosed).take(_closedShown).toList();
    if (open.isEmpty && closed.isEmpty && !isAdmin) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SquadSectionLabel('TRIPS'),
          if (open.isEmpty && closed.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Going away together? Tap Add trip expense to start a trip — everyone '
              'adds what they paid, and you settle up for it once it ends.',
              style: AppTextStyles.body(size: 12.5, color: squadMuted),
            ),
          ],
          for (final trip in [...open, ...closed]) ...[
            const SizedBox(height: 8),
            TripCard(trip: trip, ledger: ledger, me: me),
          ],
        ],
      ),
    );
  }
}

class _RecentExpenses extends StatelessWidget {
  const _RecentExpenses({required this.squad, required this.ledger, required this.me});

  final Team squad;
  final SquadLedger ledger;
  final String me;

  @override
  Widget build(BuildContext context) {
    final expenses = ledger.expenses;
    if (expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text('No expenses yet', style: AppTextStyles.title(size: 18)),
            const SizedBox(height: 6),
            Text(
              'Add the first one after your next meal out.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(size: 13, color: squadMuted),
            ),
            const SizedBox(height: 14),
            SquadPrimaryButton(
              label: '+ Add expense',
              onPressed: () => showExpenseSheet(context, teamId: squad.id, me: me),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SquadSectionLabel('RECENT EXPENSES', trailing: '${expenses.length}'),
        const SizedBox(height: 8),
        for (final expense in expenses.take(SquadHomePage.previewCount)) ...[
          ExpenseRow(
            expense: expense,
            ledger: ledger,
            me: me,
            onTap: () => context.push(AppRoutes.expenseDetail(expense.id)),
          ),
          const SizedBox(height: 8),
        ],
        if (expenses.length > SquadHomePage.previewCount)
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.match),
              child: Text(
                'See all expenses (${expenses.length})',
                style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: oweColor),
              ),
            ),
          ),
      ],
    );
  }
}
