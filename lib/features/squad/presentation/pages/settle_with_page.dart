import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/squad_ledger.dart';
import '../active_group.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import '../widgets/debt_breakdown.dart';
import '../widgets/pay_sheet.dart';
import '../widgets/payment_extras.dart';
import '../widgets/remind_button.dart';
import '../widgets/squad_widgets.dart';

/// You and one squad-mate, from a Settle card: who pays whom — counting
/// payments still waiting as paid — Pay (all or part) or "Pay later" with a
/// promised day; Remind or "Got cash" when they owe you; and how it adds
/// up: what each paid for the other and every payment between you.
/// Reached by `/settle-with/<profile id>` (`?trip=<id>` within a trip);
/// reads live from [SquadLedgerBloc].
class SettleWithPage extends StatelessWidget {
  const SettleWithPage({super.key, required this.otherId, required this.user, this.tripId});

  final String otherId;
  final AppUser user;

  /// Within this trip only, apart from the squad's own.
  final String? tripId;

  @override
  Widget build(BuildContext context) {
    final squad = watchActiveGroup(context);
    final me = user.id;
    return BlocBuilder<SquadLedgerBloc, SquadLedgerState>(
      builder: (context, state) {
        final full = state.ledger;
        final tripId = this.tripId;
        final ledger = tripId == null ? full : full?.forTrip(tripId);
        final trip = tripId == null ? null : full?.trip(tripId);
        final name = [
          ledger?.nameOf(otherId) ?? '',
          if (trip != null) '${trip.name} trip',
        ].join(' · ');
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            foregroundColor: AppColors.text,
            title: Text(name, style: AppTextStyles.title(size: 16)),
          ),
          body: squad == null || ledger == null
              ? SquadLoadingView(state: state)
              : _Content(
                  ledger: ledger,
                  me: me,
                  otherId: otherId,
                  teamId: squad.id,
                  tripId: tripId,
                ),
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.ledger,
    required this.me,
    required this.otherId,
    required this.teamId,
    this.tripId,
  });

  final SquadLedger ledger;
  final String me;
  final String otherId;
  final String teamId;
  final String? tripId;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final name = ledger.nameOf(otherId);
    // What's left once every payment sent goes through (pending counts).
    final iOwe = ledger.owedBetween(me, otherId, includePending: true);
    final theyOwe = ledger.owedBetween(otherId, me, includePending: true);
    final (fromId, toId) = iOwe > 0 ? (me, otherId) : (otherId, me);
    final amount = iOwe > 0 ? iOwe : theyOwe;
    final sentByMe = ledger.pendingCentsFrom(me, to: otherId);
    final waiting = ledger.pendingFrom(me).where((s) => s.toId == otherId).firstOrNull;
    const light = AppColors.onDark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        DarkHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(switch ((iOwe, theyOwe)) {
                (> 0, _) => 'YOU PAY ${name.toUpperCase()}',
                (_, > 0) => '${name.toUpperCase()} PAYS YOU',
                _ => 'ALL SQUARE WITH ${name.toUpperCase()}',
              }, style: AppTextStyles.label(color: AppColors.teamGold)),
              Text(
                formatMoney(amount, currency),
                style: AppTextStyles.heading(size: 34, color: AppColors.teamGold, height: 1.15),
              ),
              Text(
                [
                  if (amount > 0)
                    ?debtForWhat(ledger, fromId, toId, me)
                  else
                    'Nothing left to settle.',
                  if (amount > 0) ?partlyPaidNote(ledger, fromId, toId, me),
                  ?pendingNote(ledger, me, otherId, me),
                  if (amount > 0) ?promiseNote(ledger, fromId, toId, me),
                ].join('\n'),
                style: AppTextStyles.body(size: 12.5, color: light.withValues(alpha: 0.85)),
              ),
              if (iOwe > 0 || theyOwe > 0 || waiting != null) ...[
                const SizedBox(height: 14),
                if (iOwe > 0)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      HeroPillButton(
                        label: 'Pay ${formatMoney(iOwe, currency)}',
                        onPressed: () => showPaySheet(
                          context,
                          teamId: teamId,
                          me: me,
                          toId: otherId,
                          suggestedCents: iOwe,
                          tripId: tripId,
                        ),
                      ),
                      // One promised day at a time.
                      if (ledger.promiseFrom(me, otherId) == null)
                        HeroPillButton(
                          label: 'Pay later',
                          icon: Icons.event_outlined,
                          light: false,
                          onPressed: () =>
                              promiseToPay(context, teamId: teamId, toId: otherId, tripId: tripId),
                        ),
                    ],
                  )
                else if (sentByMe > 0)
                  HeroPillButton(
                    label: 'Pending',
                    icon: Icons.schedule_rounded,
                    onPressed: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text('Sent — waiting for $name to confirm.')),
                      ),
                  )
                else if (theyOwe > 0)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // "Remind to pay" (035): whenever they owe you, for the
                      // trip or squad — unless they've promised a day ahead.
                      if (!remindersWait(ledger, otherId, me))
                        RemindButton(
                          teamId: teamId,
                          amounts: {otherId: theyOwe},
                          tripId: tripId,
                          remindedToday: ledger.remindedToday(me, otherId),
                          onDark: true,
                        ),
                      HeroPillButton(
                        label: 'Got cash',
                        icon: Icons.payments_outlined,
                        light: false,
                        onPressed: () => showGotCashSheet(
                          context,
                          teamId: teamId,
                          fromId: otherId,
                          owedCents: theyOwe,
                          tripId: tripId,
                        ),
                      ),
                    ],
                  ),
                // Your latest payment to them still waiting: nudge them.
                if (waiting != null) ...[
                  const SizedBox(height: 10),
                  ConfirmReminderButton(
                    settlementId: waiting.id,
                    receiverName: name,
                    remindedToday: waiting.nudgedToday(),
                    onDark: true,
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SquadSectionLabel('HOW IT ADDS UP'),
        const SizedBox(height: 4),
        SquadCard(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: PairStatementView(ledger: ledger, me: me, otherId: otherId),
        ),
      ],
    );
  }
}
