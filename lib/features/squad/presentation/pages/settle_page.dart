import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
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
import '../widgets/pay_sheet.dart';
import '../widgets/squad_widgets.dart';

/// A squad's Settle tab: what you owe (or are owed), payments waiting for
/// you to confirm, the suggested payments that settle everyone, and the
/// history. "Simplify debts" (on by default) suggests the fewest payments;
/// off shows every pairwise debt.
class SettlePage extends StatefulWidget {
  const SettlePage({super.key, required this.user});

  final AppUser user;

  @override
  State<SettlePage> createState() => _SettlePageState();
}

class _SettlePageState extends State<SettlePage> {
  bool _simplify = true;

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
            final currency = ledger.currency;
            final debts = _simplify ? ledger.simplifiedDebts : ledger.rawDebts;
            final mine = ledger.simplifiedDebts.where((debt) => debt.fromId == me).toList();
            final toConfirm = ledger.awaitingConfirmationBy(me);
            final waiting = ledger.pendingFrom(me);
            final sentBack = ledger.settlements
                .where(
                  (s) =>
                      s.isRejected &&
                      s.fromId == me &&
                      DateTime.now().difference(s.respondedAt ?? s.createdAt).inDays < 7,
                )
                .toList();
            final settled = ledger.settlements.where((s) => s.isConfirmed).take(10).toList();

            void pay(String toId, int owedCents) => showPaySheet(
              context,
              teamId: squad.id,
              me: me,
              toId: toId,
              suggestedCents: (owedCents - ledger.pendingCentsFrom(me, to: toId)).clamp(
                0,
                owedCents,
              ),
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
                      Text(
                        'Simplify debts',
                        style: AppTextStyles.body(size: 13, weight: FontWeight.w700),
                      ),
                      Switch(
                        value: _simplify,
                        activeTrackColor: AppColors.accent2_700,
                        onChanged: (value) => setState(() => _simplify = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Hero(
                    ledger: ledger,
                    me: me,
                    mine: mine,
                    onPay: mine.isEmpty ? null : () => pay(mine.first.toId, mine.first.amountCents),
                  ),
                  if (toConfirm.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const SquadSectionLabel('TO CONFIRM'),
                    const SizedBox(height: 8),
                    for (final settlement in toConfirm) ...[
                      _SettlementCard(
                        title:
                            '${ledger.nameOf(settlement.fromId)} paid you '
                            '${formatMoney(settlement.amountCents, currency)}',
                        detail:
                            '${_methodDetail(settlement)} · '
                            '${formatNotificationTime(settlement.createdAt).toLowerCase()}',
                        action: 'Check',
                        onTap: () => showConfirmPaymentSheet(context, settlement: settlement),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  const SizedBox(height: 20),
                  SquadSectionLabel(
                    _simplify ? 'SUGGESTED PAYMENTS' : 'EVERY DEBT',
                    trailing: '${debts.length}',
                  ),
                  const SizedBox(height: 8),
                  if (debts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Nobody owes anything. All square.',
                        style: AppTextStyles.body(size: 13.5, color: squadMuted),
                      ),
                    ),
                  for (final debt in debts) ...[
                    _DebtRow(
                      debt: debt,
                      ledger: ledger,
                      me: me,
                      onPay: debt.fromId == me ? () => pay(debt.toId, debt.amountCents) : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (waiting.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const SquadSectionLabel('WAITING FOR CONFIRMATION'),
                    const SizedBox(height: 8),
                    for (final settlement in waiting) ...[
                      _SettlementCard(
                        title:
                            'You paid ${ledger.nameOf(settlement.toId)} '
                            '${formatMoney(settlement.amountCents, currency)}',
                        detail:
                            '${_methodDetail(settlement)} · '
                            '${formatNotificationTime(settlement.createdAt).toLowerCase()} · '
                            'not in balances yet',
                        chip: 'Pending',
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  if (sentBack.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const SquadSectionLabel('SENT BACK'),
                    const SizedBox(height: 8),
                    for (final settlement in sentBack) ...[
                      _SettlementCard(
                        title:
                            '${ledger.nameOf(settlement.toId)} sent back '
                            '${formatMoney(settlement.amountCents, currency)}',
                        detail: settlement.rejectReason == null
                            ? 'Check it and send again'
                            : '“${settlement.rejectReason}”',
                        action: 'Send again',
                        onTap: () => showPaySheet(
                          context,
                          teamId: squad.id,
                          me: me,
                          toId: settlement.toId,
                          suggestedCents: settlement.amountCents,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  if (settled.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const SquadSectionLabel('SETTLED'),
                    const SizedBox(height: 4),
                    for (final settlement in settled)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.check_rounded, size: 20, color: owedColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${ledger.nameOf(settlement.fromId, me: me)} paid '
                                '${settlement.toId == me ? 'you' : ledger.nameOf(settlement.toId)} '
                                '${formatMoney(settlement.amountCents, currency)} · '
                                '${settlement.method.label.toLowerCase()}',
                                style: AppTextStyles.body(size: 13.5),
                              ),
                            ),
                            Text(
                              formatShortDate(settlement.respondedAt ?? settlement.createdAt),
                              style: AppTextStyles.body(size: 12, color: squadMuted),
                            ),
                          ],
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

  static String _methodDetail(Settlement settlement) => switch (settlement.method) {
    SettlementMethod.qr => 'QR + slip',
    SettlementMethod.bank => 'Bank + slip',
    SettlementMethod.cash => 'Cash',
  };
}

class _Hero extends StatelessWidget {
  const _Hero({required this.ledger, required this.me, required this.mine, required this.onPay});

  final SquadLedger ledger;
  final String me;
  final List<Debt> mine;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final balance = ledger.balanceOf(me);
    final pending = ledger.pendingCentsFrom(me);
    final (label, detail) = switch (balance) {
      < 0 => (
        'YOU OWE',
        [
          if (mine.length == 1)
            'to ${ledger.nameOf(mine.single.toId)}'
          else
            'to ${mine.length} people',
          if (pending > 0) '${formatMoney(pending, currency)} of it is waiting for confirmation',
        ].join(' · '),
      ),
      > 0 => ("YOU'RE OWED", 'Friends pay you here; you confirm each one.'),
      _ => ('ALL SQUARE', 'Nothing to settle right now.'),
    };
    const light = AppColors.neutral100;
    return DarkHeroCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.label(color: AppColors.teamGold)),
                Text(
                  formatMoney(balance.abs(), currency),
                  style: AppTextStyles.heading(size: 34, color: AppColors.teamGold, height: 1.15),
                ),
                Text(
                  detail,
                  style: AppTextStyles.body(size: 12.5, color: light.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          if (onPay != null) ...[
            const SizedBox(width: 12),
            HeroPillButton(label: 'Pay', onPressed: onPay),
          ],
        ],
      ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt, required this.ledger, required this.me, required this.onPay});

  final Debt debt;
  final SquadLedger ledger;
  final String me;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final pending = debt.fromId == me ? ledger.pendingCentsFrom(me, to: debt.toId) : 0;
    final note = switch (debt) {
      _ when pending > 0 => '${formatMoney(pending, ledger.currency)} pending',
      Debt(expenseCount: final count?) => '$count ${count == 1 ? 'expense' : 'expenses'}',
      _ when debt.fromId == me => 'Tap to pay',
      _ when debt.toId == me => 'Owes you',
      _ => 'Between them',
    };
    return SquadCard(
      onTap: onPay,
      child: Row(
        children: [
          SquadAvatar(initial: ledger.member(debt.fromId)?.initial ?? '?', size: 34),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: squadMuted),
          ),
          SquadAvatar(
            initial: ledger.member(debt.toId)?.initial ?? '?',
            size: 34,
            color: AppColors.teamGold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ledger.nameOf(debt.fromId, me: me)} → ${ledger.nameOf(debt.toId, me: me)}',
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w700, height: 1.3),
                ),
                Text(note, style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.3)),
              ],
            ),
          ),
          Text(
            formatMoney(debt.amountCents, ledger.currency),
            style: AppTextStyles.body(size: 15, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.title,
    required this.detail,
    this.action,
    this.chip,
    this.onTap,
  });

  final String title;
  final String detail;
  final String? action;
  final String? chip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
              if (chip != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: oweColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chip!,
                    style: AppTextStyles.body(
                      size: 11.5,
                      weight: FontWeight.w800,
                      color: oweColor,
                      height: 1.2,
                    ),
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
