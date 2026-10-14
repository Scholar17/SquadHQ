import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../notifications/presentation/pages/notifications_page.dart'
    show formatNotificationTime;
import '../../domain/entities/settlement.dart';
import '../../domain/entities/squad_ledger.dart';
import '../active_group.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import '../widgets/confirm_payment_sheet.dart';
import '../widgets/debt_breakdown.dart';
import '../widgets/pay_sheet.dart';
import '../widgets/payment_extras.dart';
import '../widgets/remind_button.dart';
import '../widgets/squad_widgets.dart';
import '../widgets/trip_card.dart';

/// A squad's Settle tab: everyone you pay and everyone who pays you, each
/// debt person to person (across every expense between you, less
/// confirmed payments), payments waiting for you to confirm, the rest of
/// the squad's debts, and the history.
class SettlePage extends StatefulWidget {
  const SettlePage({super.key, required this.user});

  final AppUser user;

  @override
  State<SettlePage> createState() => _SettlePageState();
}

class _SettlePageState extends State<SettlePage> {
  /// The "You pay" list — the hero's "Pay" scrolls here when you owe more
  /// than one person.
  final _payKey = GlobalKey();

  void _scrollToPay() {
    final target = _payKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
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
            final currency = ledger.currency;
            // What's left once every payment sent goes through (pending
            // counts): nobody's asked again for what they've already sent.
            final debts = ledger.openDebts;
            final toPay = debts.where((debt) => debt.fromId == me).toList();
            final toGet = debts.where((debt) => debt.toId == me).toList();
            final others = debts.where((debt) => debt.fromId != me && debt.toId != me).toList();
            // "Remind to pay" (035): anyone who owes you, for what they owe
            // you — but not someone who's promised a day still ahead.
            final remindable = {
              for (final debt in toGet)
                if (!remindersWait(ledger, debt.fromId, me)) debt.fromId: debt.amountCents,
            };
            // Trip payments are settled apart but confirmed here too.
            final toConfirm = [
              ...ledger.awaitingConfirmationBy(me),
              ...ledger.tripPaymentsAwaiting(me),
            ];
            // Payments you sent that are still waiting show on that person's
            // You pay card with "Remind to confirm" — even once they cover
            // everything (the card then shows what you sent, Pending).
            final payingTo = {for (final debt in toPay) debt.toId};
            final sentOnly = [
              for (final toId in {for (final s in ledger.pendingFrom(me)) s.toId})
                if (!payingTo.contains(toId)) Debt(fromId: me, toId: toId, amountCents: 0),
            ];
            // Sent back by the receiver and not sent again yet. Once it's
            // sent again it's just waiting, on the You pay card.
            final sentBack = [
              for (final (:rejected, :resent) in ledger.sentBackTo(me))
                if (resent == null) rejected,
            ];
            final settled = ledger.settlements.where((s) => s.isConfirmed).toList();
            // Not square while a payment is still waiting: open debts count
            // pending as paid, so they can be empty with one in flight.
            final allSquare = debts.isEmpty && sentOnly.isEmpty && toConfirm.isEmpty;

            void pay(String toId, int owedCents) => showPaySheet(
              context,
              teamId: squad.id,
              me: me,
              toId: toId,
              // Already net of anything you've sent that's still pending.
              suggestedCents: owedCents,
            );

            Widget debtRow(Debt debt) => _DebtRow(
              debt: debt,
              ledger: ledger,
              me: me,
              teamId: squad.id,
              onPay: debt.fromId == me ? () => pay(debt.toId, debt.amountCents) : null,
              canRemind: debt.toId == me,
            );

            return RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => refreshSquad(context),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Settle up', style: AppTextStyles.heading(size: 24))),
                      IconButton(
                        onPressed: () => _openHistory(context, me),
                        icon: const Icon(Icons.history_rounded),
                        tooltip: 'Payment history',
                        color: AppColors.text,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Hero(
                    ledger: ledger,
                    me: me,
                    toPay: toPay,
                    toGet: toGet,
                    // One person: pay them. Several: pick who, in the list.
                    onPay: switch (toPay) {
                      [] => null,
                      [final only] => () => pay(only.toId, only.amountCents),
                      _ => _scrollToPay,
                    },
                    remindAll: remindable.isEmpty
                        ? null
                        : RemindButton(
                            teamId: squad.id,
                            amounts: remindable,
                            remindedToday: remindable.keys.every(
                              (id) => ledger.remindedToday(me, id),
                            ),
                            label: remindable.length == 1 ? 'Remind' : 'Remind all',
                            onDark: true,
                          ),
                  ),
                  _ReminderDayRow(
                    day: ledger.member(me)?.reminderDay,
                    onTap: () => showReminderDaySheet(
                      context,
                      teamId: squad.id,
                      current: ledger.member(me)?.reminderDay,
                    ),
                  ),
                  if (toConfirm.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SquadSectionLabel('TO CONFIRM', trailing: '${toConfirm.length}'),
                    const SizedBox(height: 8),
                    SeeMoreList(
                      children: [
                        for (final settlement in toConfirm)
                          CheckPaymentCard(
                            title:
                                '${ledger.nameOf(settlement.fromId)} paid you '
                                '${formatMoney(settlement.amountCents, currency)}'
                                '${ledger.partOf(settlement) == null ? '' : ' · partial'}',
                            detail: [
                              if (ledger.partOf(settlement) case final part?)
                                'Part of ${formatMoney(part.owed, currency)} · '
                                    '${formatMoney(part.left, currency)} left after',
                              _methodDetail(settlement),
                              formatNotificationTime(settlement.createdAt).toLowerCase(),
                              if (settlement.tripId case final tripId?)
                                if (ledger.trip(tripId) case final trip?) '${trip.name} trip',
                            ].join(' · '),
                            onTap: () => showConfirmPaymentSheet(context, settlement: settlement),
                          ),
                      ],
                    ),
                  ],
                  if (allSquare) ...[
                    const SizedBox(height: 20),
                    const _AllSquare(),
                  ] else ...[
                    const SizedBox(height: 20),
                    SquadSectionLabel(
                      key: _payKey,
                      'YOU PAY',
                      trailing: toPay.isEmpty ? null : formatMoney(_total(toPay), currency),
                    ),
                    const SizedBox(height: 8),
                    if (toPay.isEmpty && sentOnly.isEmpty)
                      const _EmptySection("You don't owe anyone.")
                    else
                      SeeMoreList(
                        previewCount: 4,
                        children: [
                          for (final debt in [...toPay, ...sentOnly]) debtRow(debt),
                        ],
                      ),
                  ],
                  if (sentBack.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SquadSectionLabel('SENT BACK', trailing: '${sentBack.length}'),
                    const SizedBox(height: 8),
                    SeeMoreList(
                      previewCount: 2,
                      children: [
                        for (final rejected in sentBack)
                          _SettlementCard(
                            title:
                                '${ledger.nameOf(rejected.toId)} sent back '
                                '${formatMoney(rejected.amountCents, currency)}',
                            detail: rejected.rejectReason == null
                                ? 'Check it and send again'
                                : '“${rejected.rejectReason}”',
                            action: 'Send again',
                            onTap: () => showPaySheet(
                              context,
                              teamId: squad.id,
                              me: me,
                              toId: rejected.toId,
                              suggestedCents: rejected.amountCents,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (!allSquare) ...[
                    const SizedBox(height: 20),
                    SquadSectionLabel(
                      'YOU GET',
                      trailing: toGet.isEmpty ? null : formatMoney(_total(toGet), currency),
                    ),
                    const SizedBox(height: 8),
                    if (toGet.isEmpty)
                      const _EmptySection('Nobody owes you.')
                    else
                      SeeMoreList(
                        previewCount: 4,
                        children: [for (final debt in toGet) debtRow(debt)],
                      ),
                  ],
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SquadSectionLabel('REST OF THE SQUAD', trailing: '${others.length}'),
                    const SizedBox(height: 8),
                    SeeMoreList(children: [for (final debt in others) debtRow(debt)]),
                  ],
                  // Trips settle on their own; here's where you stand on each.
                  if (ledger.trips.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SquadSectionLabel('TRIPS', trailing: '${ledger.trips.length}'),
                    const SizedBox(height: 4),
                    Text(
                      'Each trip settles on its own — open one to pay or remind.',
                      style: AppTextStyles.body(size: 12, color: squadMuted),
                    ),
                    const SizedBox(height: 8),
                    SeeMoreList(
                      children: [
                        for (final trip in ledger.trips)
                          TripCard(trip: trip, ledger: ledger, me: me),
                      ],
                    ),
                  ],
                  if (settled.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SquadSectionLabel('SETTLED', trailing: '${settled.length}'),
                    const SizedBox(height: 4),
                    for (final settlement in settled.take(_recentSettledCount))
                      _SettledRow(settlement: settlement, ledger: ledger, me: me),
                    if (settled.length > _recentSettledCount)
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _openHistory(context, me),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.chevron_right_rounded, size: 18),
                          label: Text(
                            'Full history (${settled.length})',
                            style: AppTextStyles.body(size: 13, weight: FontWeight.w700),
                          ),
                          style: TextButton.styleFrom(foregroundColor: oweColor),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static int _total(List<Debt> debts) => debts.fold(0, (sum, debt) => sum + debt.amountCents);

  static const _recentSettledCount = 5;

  /// Every confirmed payment — the squad's and each trip's — like the
  /// football Wallet's bill history.
  static Future<void> _openHistory(BuildContext context, String me) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => _SettleHistoryPage(me: me)));

  static String _methodDetail(Settlement settlement) => switch (settlement.method) {
    SettlementMethod.qr => 'QR + slip',
    SettlementMethod.bank => 'Bank + slip',
    SettlementMethod.cash => 'Cash',
  };
}

/// What you pay and what you get side by side, your net, and the actions.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.ledger,
    required this.me,
    required this.toPay,
    required this.toGet,
    required this.onPay,
    this.remindAll,
  });

  final SquadLedger ledger;
  final String me;
  final List<Debt> toPay;
  final List<Debt> toGet;
  final VoidCallback? onPay;

  /// "Remind all", when people owe you.
  final Widget? remindAll;

  static String _people(int count) => '$count ${count == 1 ? 'person' : 'people'}';

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final payTotal = toPay.fold(0, (sum, debt) => sum + debt.amountCents);
    final getTotal = toGet.fold(0, (sum, debt) => sum + debt.amountCents);
    final pending = ledger.pendingCentsFrom(me);
    // From the same open debts as the cards, so the numbers agree.
    final balance = getTotal - payTotal;
    final net = switch (balance) {
      < 0 => 'Overall you owe ${formatMoney(-balance, currency)}',
      > 0 => "Overall you're owed ${formatMoney(balance, currency)}",
      _ => "Overall you're even",
    };
    const light = AppColors.onDark;
    final muted = light.withValues(alpha: 0.7);
    return DarkHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'YOU PAY',
                    amount: formatMoney(payTotal, currency),
                    detail: switch (toPay.length) {
                      0 => 'Nothing to pay',
                      1 => 'to ${ledger.nameOf(toPay.single.toId)}',
                      final n => 'to ${_people(n)}',
                    },
                    color: payTotal > 0 ? AppColors.teamGold : muted,
                  ),
                ),
                VerticalDivider(width: 28, thickness: 1, color: light.withValues(alpha: 0.15)),
                Expanded(
                  child: _HeroStat(
                    label: 'YOU GET',
                    amount: formatMoney(getTotal, currency),
                    detail: switch (toGet.length) {
                      0 => 'Nothing to get',
                      1 => 'from ${ledger.nameOf(toGet.single.fromId)}',
                      final n => 'from ${_people(n)}',
                    },
                    color: getTotal > 0 ? AppColors.accent2_100 : muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            [
              net,
              if (pending > 0) '${formatMoney(pending, currency)} sent, waiting for confirmation',
            ].join(' · '),
            style: AppTextStyles.body(size: 12.5, color: light.withValues(alpha: 0.85)),
          ),
          if (onPay != null || remindAll != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onPay != null)
                  Expanded(
                    child: HeroPillButton(
                      label: 'Pay',
                      // Several people: it scrolls down to choose who.
                      icon: toPay.length > 1 ? Icons.arrow_downward_rounded : null,
                      onPressed: onPay,
                    ),
                  ),
                if (onPay != null && remindAll != null) const SizedBox(width: 10),
                ?remindAll,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.amount,
    required this.detail,
    required this.color,
  });

  final String label;
  final String amount;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label(color: color)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(amount, style: AppTextStyles.heading(size: 28, color: color, height: 1.15)),
        ),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(
            size: 12.5,
            color: AppColors.onDark.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// One debt. Yours (either way) shows the other person, "Pay" or
/// "Remind", and a line on why — tap for the full story and your history
/// with them. Between two others it shows both people.
class _DebtRow extends StatelessWidget {
  const _DebtRow({
    required this.debt,
    required this.ledger,
    required this.me,
    required this.teamId,
    required this.onPay,
    required this.canRemind,
  });

  final Debt debt;
  final SquadLedger ledger;
  final String me;
  final String teamId;
  final VoidCallback? onPay;

  /// Owed to you: "Remind to pay".
  final bool canRemind;

  @override
  Widget build(BuildContext context) {
    final paying = debt.fromId == me;
    final getting = debt.toId == me;
    final mine = paying || getting;
    final other = paying ? debt.toId : debt.fromId;
    final pending = ledger.pendingCentsFrom(debt.fromId, to: debt.toId);
    // Nothing left once what you sent goes through: show what you sent.
    final allSent = paying && debt.amountCents == 0;
    // Yours: just what it's for — the rest is on the person's page — and
    // any payment still waiting, already counted in the amount.
    final note = mine
        ? [
            ?debtForWhat(ledger, debt.fromId, debt.toId, me),
            if (!allSent) ?partlyPaidNote(ledger, debt.fromId, debt.toId, me),
            ?pendingNote(ledger, debt.fromId, debt.toId, me),
            if (!allSent) ?promiseNote(ledger, debt.fromId, debt.toId, me),
          ].join('\n')
        : [
            if (debt.expenseCount case final count?)
              '$count ${count == 1 ? 'expense' : 'expenses'}',
            if (pending > 0) '${formatMoney(pending, ledger.currency)} pending',
          ].join(' · ');
    // Your latest payment to them still waiting: nudge them to confirm.
    final waiting = paying
        ? ledger.pendingFrom(me).where((s) => s.toId == debt.toId).firstOrNull
        : null;
    final row = Row(
      children: [
        if (mine)
          SquadAvatar(
            initial: ledger.member(other)?.initial ?? '?',
            photoUrl: ledger.member(other)?.avatarUrl,
            size: 34,
            color: paying ? AppColors.teamGold : null,
          )
        else ...[
          SquadAvatar(
            initial: ledger.member(debt.fromId)?.initial ?? '?',
            photoUrl: ledger.member(debt.fromId)?.avatarUrl,
            size: 30,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward_rounded, size: 14, color: squadMuted),
          ),
          SquadAvatar(
            initial: ledger.member(debt.toId)?.initial ?? '?',
            photoUrl: ledger.member(debt.toId)?.avatarUrl,
            size: 30,
          ),
        ],
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
              if (note.isNotEmpty)
                Text(note, style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.3)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(allSent ? pending : debt.amountCents, ledger.currency),
              style: AppTextStyles.body(
                size: 15,
                weight: FontWeight.w800,
                color: paying ? oweColor : (getting ? owedColor : null),
              ),
            ),
            // Yours to pay: "Pay", or "Pending" once what you've sent
            // covers it.
            if (paying) ...[
              const SizedBox(height: 4),
              PayStatusButton(
                status: allSent ? PayStatus.pending : PayStatus.pay,
                onPay: allSent ? null : onPay,
              ),
            ],
            // Owed to you: nudge them (once a day) — unless they've promised
            // a day that's still ahead.
            if (getting && canRemind && !remindersWait(ledger, debt.fromId, me)) ...[
              const SizedBox(height: 4),
              RemindButton(
                teamId: teamId,
                amounts: {debt.fromId: debt.amountCents},
                remindedToday: ledger.remindedToday(me, debt.fromId),
              ),
            ],
          ],
        ),
        if (mine) Icon(Icons.chevron_right_rounded, size: 20, color: squadMuted),
      ],
    );
    return SquadCard(
      onTap: mine ? () => context.push(AppRoutes.settleWith(other)) : null,
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
}

/// "Reminders: last day of the month · Change" — when you get the monthly
/// "you owe" reminder in this squad.
class _ReminderDayRow extends StatelessWidget {
  const _ReminderDayRow({required this.day, required this.onTap});

  final int? day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('reminder-day'),
      borderRadius: AppRadius.sm,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.notifications_none_rounded, size: 18, color: squadMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                day == null
                    ? 'Reminders: last day of the month'
                    : 'Reminders: the ${ordinal(day!)} of each month',
                style: AppTextStyles.body(size: 13, color: squadMuted, weight: FontWeight.w600),
              ),
            ),
            Text(
              'Change',
              style: AppTextStyles.body(size: 13, weight: FontWeight.w800, color: oweColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// "You don't owe anyone." under an empty section.
class _EmptySection extends StatelessWidget {
  const _EmptySection(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Text(text, style: AppTextStyles.body(size: 13, color: squadMuted)),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({required this.title, required this.detail, this.action, this.onTap});

  final String title;
  final String detail;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body(size: 14, weight: FontWeight.w700, height: 1.3),
                    ),
                    Text(
                      detail,
                      style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (action != null)
                Text(
                  action!,
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w800, color: oweColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One confirmed payment: who paid whom, how much, how, and when.
class _SettledRow extends StatelessWidget {
  const _SettledRow({required this.settlement, required this.ledger, required this.me});

  final Settlement settlement;
  final SquadLedger ledger;
  final String me;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        children: [
          Icon(Icons.check_rounded, size: 20, color: owedColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${ledger.nameOf(settlement.fromId, me: me)} paid '
              '${settlement.toId == me ? 'you' : ledger.nameOf(settlement.toId)} '
              '${formatMoney(settlement.amountCents, ledger.currency)}'
              '${settlement.isPartlyReceived ? ' of ${formatMoney(settlement.sentCents!, ledger.currency)} sent' : ''} · '
              '${settlement.method.label.toLowerCase()}'
              '${switch (settlement.tripId) {
                final id? => ' · ${ledger.trip(id)?.name ?? 'a'} trip',
                null => '',
              }}',
              style: AppTextStyles.body(size: 13.5),
            ),
          ),
          Text(
            formatShortDate(settlement.respondedAt ?? settlement.createdAt),
            style: AppTextStyles.body(size: 12, color: squadMuted),
          ),
        ],
      ),
    );
  }
}

/// Every confirmed payment, newest first under month headings — the
/// squad's and its trips' (labelled) — read live from [SquadLedgerBloc].
class _SettleHistoryPage extends StatelessWidget {
  const _SettleHistoryPage({required this.me});

  final String me;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Payment history', style: AppTextStyles.title(size: 16)),
      ),
      body: BlocBuilder<SquadLedgerBloc, SquadLedgerState>(
        builder: (context, state) {
          final ledger = state.ledger;
          if (ledger == null) return SquadLoadingView(state: state);
          DateTime at(Settlement s) => s.respondedAt ?? s.createdAt;
          final settled = [
            ...ledger.settlements.where((s) => s.isConfirmed),
            ...ledger.tripSettlements.where((s) => s.isConfirmed),
          ]..sort((a, b) => at(b).compareTo(at(a)));
          if (settled.isEmpty) {
            return Center(
              child: Text(
                'No payments yet.',
                style: AppTextStyles.body(size: 13.5, color: squadMuted),
              ),
            );
          }
          final months = <String, List<Settlement>>{};
          for (final s in settled) {
            months.putIfAbsent(formatMonthLabel(at(s)), () => []).add(s);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              for (final MapEntry(key: month, value: payments) in months.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: SquadSectionLabel(
                    month,
                    trailing: formatMoney(
                      payments.fold(0, (sum, s) => sum + s.amountCents),
                      ledger.currency,
                    ),
                  ),
                ),
                for (final settlement in payments)
                  _SettledRow(settlement: settlement, ledger: ledger, me: me),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// No debts left in the squad.
class _AllSquare extends StatelessWidget {
  const _AllSquare();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.accent2_100, shape: BoxShape.circle),
            child: Icon(Icons.handshake_outlined, size: 26, color: owedColor),
          ),
          const SizedBox(height: 12),
          Text('All square', style: AppTextStyles.title(size: 18)),
          const SizedBox(height: 4),
          Text(
            'Nobody owes anything. New expenses will show up here.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 13, color: squadMuted),
          ),
        ],
      ),
    );
  }
}
