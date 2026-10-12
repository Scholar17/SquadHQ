import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/entities/trip.dart';
import '../active_group.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import '../widgets/confirm_payment_sheet.dart';
import '../widgets/debt_breakdown.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/pay_sheet.dart';
import '../widgets/remind_button.dart';
import '../widgets/squad_widgets.dart';
import '../widgets/trip_sheet.dart';

/// One trip: what's been spent, who paid what, every expense by day, and —
/// once an admin closes it — settling up for the trip on its own. While
/// it's open, the people on it add what they paid ("Add trip expense").
/// Reached by `/trip/<id>`; reads live from [SquadLedgerBloc].
class TripPage extends StatelessWidget {
  const TripPage({super.key, required this.tripId, required this.user});

  final String tripId;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final squad = watchActiveGroup(context);
    return BlocConsumer<SquadLedgerBloc, SquadLedgerState>(
      listenWhen: (previous, current) => current is SquadLedgerFailure,
      listener: (context, state) {
        if (state case SquadLedgerFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final full = state.ledger;
        final trip = full?.trip(tripId);
        final isAdmin = full?.member(user.id)?.isAdmin ?? false;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            foregroundColor: AppColors.text,
            title: Text(trip?.name ?? '', style: AppTextStyles.title(size: 16)),
            actions: [
              if (trip != null && squad != null && isAdmin && !trip.isClosed)
                IconButton(
                  tooltip: 'Edit trip',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      showTripSheet(context, teamId: squad.id, me: user.id, editing: trip),
                ),
            ],
          ),
          body: switch ((squad, full, trip)) {
            (final squad?, final full?, final trip?) => _Content(
              trip: trip,
              ledger: full.forTrip(trip.id),
              me: user.id,
              teamId: squad.id,
              isAdmin: isAdmin,
              busy: state is SquadLedgerSubmitting,
            ),
            (_, final _?, null) => Center(
              child: Text(
                'This trip no longer exists.',
                style: AppTextStyles.body(size: 13.5, color: squadMuted),
              ),
            ),
            _ => SquadLoadingView(state: state),
          },
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.trip,
    required this.ledger,
    required this.me,
    required this.teamId,
    required this.isAdmin,
    required this.busy,
  });

  final Trip trip;

  /// The trip's own expenses and payments.
  final SquadLedger ledger;
  final String me;
  final String teamId;
  final bool isAdmin;

  /// A save is in flight.
  final bool busy;

  Future<void> _setClosed(BuildContext context, {required bool closed}) async {
    final bloc = context.read<SquadLedgerBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(closed ? 'Close ${trip.name}?' : 'Reopen ${trip.name}?'),
        content: Text(
          closed
              ? 'Expenses get locked and everyone settles up for the trip. '
                    'You can reopen it if something needs changing.'
              : 'People can add and change trip expenses again. Settling up '
                    'waits until it closes again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(closed ? 'Close trip' : 'Reopen'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(TripClosedChanged(trip.id, closed: closed));
  }

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final total = ledger.expenses.fold(0, (sum, e) => sum + e.amountCents);
    final people = trip.memberIds.length;
    final canAdd = !trip.isClosed && (trip.includes(me) || isAdmin);
    final today = trip.dayOf(DateTime.now());
    final status = trip.isClosed
        ? 'CLOSED · SETTLING UP'
        : (today >= 1 && today <= trip.dayCount ? 'DAY $today OF ${trip.dayCount}' : 'OPEN');
    const light = AppColors.onDark;
    // Payments still waiting count as paid, as in Settle.
    final debts = trip.isClosed ? ledger.openDebts : const <Debt>[];
    final toPay = debts.where((d) => d.fromId == me).toList();
    final toGet = debts.where((d) => d.toId == me).toList();
    final others = debts.where((d) => d.fromId != me && d.toId != me).toList();
    final toConfirm = ledger.awaitingConfirmationBy(me);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        DarkHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$status · ${formatTripDates(trip.startsOn, trip.endsOn)}',
                style: AppTextStyles.label(color: AppColors.teamGold),
              ),
              Text(
                formatMoney(total, currency),
                style: AppTextStyles.heading(size: 34, color: AppColors.teamGold, height: 1.15),
              ),
              Text(
                [
                  '$people people',
                  if (total > 0) '${formatMoney(total ~/ people, currency)} each on average',
                  if (trip.includes(me))
                    'you paid ${formatMoney(_paidBy(me), currency)}, '
                        'your share ${formatMoney(_shareOf(me), currency)}',
                ].join(' · '),
                style: AppTextStyles.body(size: 12.5, color: light.withValues(alpha: 0.85)),
              ),
              if (canAdd || isAdmin) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (canAdd)
                      Expanded(
                        child: HeroPillButton(
                          label: 'Add trip expense',
                          icon: Icons.add_rounded,
                          onPressed: () =>
                              showExpenseSheet(context, teamId: teamId, me: me, tripId: trip.id),
                        ),
                      ),
                    if (canAdd && isAdmin) const SizedBox(width: 10),
                    if (isAdmin)
                      Expanded(
                        child: HeroPillButton(
                          label: trip.isClosed ? 'Reopen' : 'Close trip',
                          icon: trip.isClosed
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          light: false,
                          onPressed: busy
                              ? null
                              : () => _setClosed(context, closed: !trip.isClosed),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (!trip.isClosed) ...[
          const SizedBox(height: 10),
          Text(
            'Settling up starts once an admin closes the trip.',
            style: AppTextStyles.body(size: 12, color: squadMuted),
          ),
        ],
        if (toConfirm.isNotEmpty) ...[
          const SizedBox(height: 20),
          SquadSectionLabel('TO CONFIRM', trailing: '${toConfirm.length}'),
          const SizedBox(height: 8),
          for (final settlement in toConfirm) ...[
            CheckPaymentCard(
              title:
                  '${ledger.nameOf(settlement.fromId)} paid you '
                  '${formatMoney(settlement.amountCents, currency)}'
                  '${ledger.partOf(settlement) == null ? '' : ' · partial'}',
              onTap: () => showConfirmPaymentSheet(context, settlement: settlement),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (trip.isClosed) ...[
          const SizedBox(height: 20),
          if (debts.isEmpty)
            Text(
              'Everyone on the trip is settled up.',
              style: AppTextStyles.body(size: 14, weight: FontWeight.w700, color: owedColor),
            )
          else ...[
            if (toPay.isNotEmpty) ...[
              SquadSectionLabel(
                'YOU PAY',
                trailing: formatMoney(toPay.fold(0, (s, d) => s + d.amountCents), currency),
              ),
              const SizedBox(height: 8),
              SeeMoreList(
                previewCount: 4,
                children: [for (final debt in toPay) _debtCard(context, debt)],
              ),
              const SizedBox(height: 12),
            ],
            if (toGet.isNotEmpty) ...[
              SquadSectionLabel(
                'YOU GET',
                trailing: formatMoney(toGet.fold(0, (s, d) => s + d.amountCents), currency),
              ),
              const SizedBox(height: 8),
              SeeMoreList(
                previewCount: 4,
                children: [for (final debt in toGet) _debtCard(context, debt)],
              ),
              const SizedBox(height: 12),
            ],
            if (others.isNotEmpty) ...[
              SquadSectionLabel('REST OF THE TRIP', trailing: '${others.length}'),
              const SizedBox(height: 8),
              SeeMoreList(children: [for (final debt in others) _debtCard(context, debt)]),
            ],
          ],
        ],
        const SizedBox(height: 20),
        SquadSectionLabel('WHO PAID WHAT'),
        const SizedBox(height: 8),
        SquadCard(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(
            children: [
              for (final id in trip.memberIds)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SquadAvatar(
                        initial: ledger.member(id)?.initial ?? '?',
                        photoUrl: ledger.member(id)?.avatarUrl,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ledger.nameOf(id, me: me),
                          style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'paid ${formatMoney(_paidBy(id), currency)}',
                            style: AppTextStyles.body(size: 13, weight: FontWeight.w700),
                          ),
                          Text(
                            'share ${formatMoney(_shareOf(id), currency)}',
                            style: AppTextStyles.body(size: 11.5, color: squadMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SquadSectionLabel('EXPENSES', trailing: '${ledger.expenses.length}'),
        ..._expensesByDay(context),
      ],
    );
  }

  int _paidBy(String id) => ledger.expenses.fold(0, (sum, e) => sum + e.paidBy(id));

  int _shareOf(String id) => ledger.expenses.fold(0, (sum, e) => sum + e.shareOf(id));

  /// Yours: Pay (or Pending, with "Remind to confirm") and why; tap for the
  /// person's page within the trip. Between two others: both names.
  Widget _debtCard(BuildContext context, Debt debt) {
    final currency = ledger.currency;
    final paying = debt.fromId == me;
    final getting = debt.toId == me;
    final mine = paying || getting;
    final other = paying ? debt.toId : debt.fromId;
    final waiting = paying
        ? ledger.pendingFrom(me).where((s) => s.toId == debt.toId).firstOrNull
        : null;
    final row = Row(
      children: [
        SquadAvatar(
          initial: ledger.member(mine ? other : debt.fromId)?.initial ?? '?',
          photoUrl: ledger.member(mine ? other : debt.fromId)?.avatarUrl,
          size: 34,
          color: paying ? AppColors.teamGold : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mine
                    ? ledger.nameOf(other)
                    : '${ledger.nameOf(debt.fromId)} → ${ledger.nameOf(debt.toId)}',
                style: AppTextStyles.body(size: 14, weight: FontWeight.w700, height: 1.3),
              ),
              if (mine)
                if (debtForWhat(ledger, debt.fromId, debt.toId, me) case final why?)
                  Text(why, style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.3)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(debt.amountCents, currency),
              style: AppTextStyles.body(
                size: 15,
                weight: FontWeight.w800,
                color: paying ? oweColor : (getting ? owedColor : null),
              ),
            ),
            if (paying) ...[
              const SizedBox(height: 4),
              PayStatusButton(
                status: PayStatus.pay,
                onPay: () => showPaySheet(
                  context,
                  teamId: teamId,
                  me: me,
                  toId: debt.toId,
                  suggestedCents: debt.amountCents,
                  tripId: trip.id,
                ),
              ),
            ],
            // Owed to you for the trip: "Remind to pay", once a day.
            if (getting) ...[
              const SizedBox(height: 4),
              RemindButton(
                teamId: teamId,
                amounts: {debt.fromId: debt.amountCents},
                tripId: trip.id,
                remindedToday: ledger.remindedToday(me, debt.fromId),
              ),
            ],
          ],
        ),
        if (mine) Icon(Icons.chevron_right_rounded, size: 20, color: squadMuted),
      ],
    );
    return SquadCard(
      onTap: mine ? () => context.push(AppRoutes.settleWith(other, tripId: trip.id)) : null,
      child: waiting == null
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row,
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: ConfirmReminderButton(
                    settlementId: waiting.id,
                    receiverName: ledger.nameOf(waiting.toId),
                    remindedToday: waiting.nudgedToday(),
                  ),
                ),
              ],
            ),
    );
  }

  /// Every expense, newest day first, under "Day 2 · Sat 11 Oct".
  List<Widget> _expensesByDay(BuildContext context) {
    if (ledger.expenses.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            trip.isClosed ? 'No expenses on this trip.' : 'Nothing yet — add the first one.',
            style: AppTextStyles.body(size: 13, color: squadMuted),
          ),
        ),
      ];
    }
    // Newest first already; grouped by day, the long days folding away.
    final days = <int, List<Expense>>{};
    for (final expense in ledger.expenses) {
      days.putIfAbsent(trip.dayOf(expense.spentAt), () => []).add(expense);
    }
    final widgets = <Widget>[];
    for (final MapEntry(key: day, value: expenses) in days.entries) {
      final date = formatShortDate(expenses.first.spentAt).toUpperCase();
      widgets
        ..add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: SquadSectionLabel(
              day >= 1 && day <= trip.dayCount ? 'DAY $day · $date' : date,
              trailing: formatMoney(
                expenses.fold(0, (sum, e) => sum + e.amountCents),
                ledger.currency,
              ),
            ),
          ),
        )
        ..add(
          SeeMoreList(
            previewCount: 4,
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
        );
    }
    return widgets;
  }
}
