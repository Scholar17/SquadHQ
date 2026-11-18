import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../personal/presentation/personal_formatting.dart' show formatDayLabel;
import '../../../squad/domain/entities/settlement.dart' show SettlementStatus;
import '../../../squad/domain/entities/squad_ledger.dart';
import '../../../squad/presentation/active_group.dart';
import '../../../squad/presentation/bloc/squad_ledger_bloc.dart';
import '../../../squad/presentation/squad_formatting.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../domain/entities/buddy.dart';
import '../cubit/buddy_cubit.dart';
import '../widgets/buddy_expense_sheet.dart';
import '../widgets/buddy_pay_sheet.dart';

/// You and one squad-mate on buddy expenses: the balance between you
/// (apart from the squad's), paying back, payments to confirm, and every
/// buddy expense and payment. Reached by `/buddy/<profile id>`.
class BuddyPage extends StatefulWidget {
  const BuddyPage({super.key, required this.buddyId, required this.user});

  final String buddyId;
  final AppUser user;

  @override
  State<BuddyPage> createState() => _BuddyPageState();
}

class _BuddyPageState extends State<BuddyPage> {
  final _cubit = sl<BuddyCubit>();
  String? _loadedFor;

  void _loadFor(String teamId) {
    if (_loadedFor == teamId) return;
    _loadedFor = teamId;
    _cubit.load(teamId);
  }

  @override
  Widget build(BuildContext context) {
    final squad = watchActiveGroup(context);
    if (squad != null) _loadFor(squad.id);
    final ledger = context.watch<SquadLedgerBloc>().state.ledger;
    final me = widget.user.id;
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<BuddyCubit, BuddyState>(
        listenWhen: (previous, current) => current.error != null && previous.error != current.error,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.error!))),
        builder: (context, state) {
          final buddies = state.ledger;
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              backgroundColor: AppColors.bg,
              elevation: 0,
              foregroundColor: AppColors.text,
              title: Text(
                ledger == null ? 'Buddy' : '${ledger.nameOf(widget.buddyId)} · buddy',
                style: AppTextStyles.title(size: 16),
              ),
            ),
            floatingActionButton: squad == null || ledger == null
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => showBuddyExpenseSheet(
                      context,
                      teamId: squad.id,
                      me: me,
                      buddyId: widget.buddyId,
                    ),
                    backgroundColor: AppColors.accentFill,
                    foregroundColor: AppColors.onDark,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
            body: squad == null || ledger == null || buddies == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: () => _cubit.load(squad.id),
                    child: _Content(
                      teamId: squad.id,
                      me: me,
                      buddyId: widget.buddyId,
                      ledger: ledger,
                      buddies: buddies,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.teamId,
    required this.me,
    required this.buddyId,
    required this.ledger,
    required this.buddies,
  });

  final String teamId;
  final String me;
  final String buddyId;
  final SquadLedger ledger;
  final BuddyLedger buddies;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final name = ledger.nameOf(buddyId);
    final balance = buddies.balanceWith(buddyId);
    final toConfirm = buddies.awaitingMeFrom(buddyId);
    final mine = [
      for (final s in buddies.settlementsWith(buddyId))
        if (s.isPending && s.fromId == me) s,
    ];
    final history = <({DateTime at, Widget card})>[
      for (final expense in buddies.expensesWith(buddyId))
        (at: expense.spentAt, card: _ExpenseCard(expense: expense, me: me, ledger: ledger, teamId: teamId)),
      for (final settlement in buddies.settlementsWith(buddyId))
        (at: settlement.createdAt, card: _PaymentCard(settlement: settlement, me: me, ledger: ledger)),
    ]..sort((a, b) => b.at.compareTo(a.at));
    const light = AppColors.onDark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      children: [
        DarkHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(switch (balance) {
                < 0 => 'YOU PAY ${name.toUpperCase()}',
                > 0 => '${name.toUpperCase()} PAYS YOU',
                _ => 'ALL SQUARE WITH ${name.toUpperCase()}',
              }, style: AppTextStyles.label(color: AppColors.teamGold)),
              Text(
                formatMoney(balance.abs(), currency),
                key: const ValueKey('buddy-balance'),
                style: AppTextStyles.heading(size: 34, color: AppColors.teamGold, height: 1.15),
              ),
              Text(
                [
                  'Just between you two · not in the squad balance',
                  if (mine.isNotEmpty)
                    'You sent ${formatMoney(mine.fold(0, (a, s) => a + s.amountCents), currency)} · waiting for $name to confirm',
                ].join('\n'),
                style: AppTextStyles.body(size: 12.5, color: light.withValues(alpha: 0.85)),
              ),
              if (balance != 0) ...[
                const SizedBox(height: 14),
                HeroPillButton(
                  label: balance < 0
                      ? 'I paid ${formatMoney(-balance, currency)}'
                      : 'Mark as received',
                  icon: balance < 0 ? null : Icons.payments_outlined,
                  light: balance < 0,
                  onPressed: () => showBuddyPaySheet(
                    context,
                    teamId: teamId,
                    me: me,
                    otherId: buddyId,
                    owedCents: balance.abs(),
                    ledger: ledger,
                    received: balance > 0,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (toConfirm.isNotEmpty) ...[
          const SizedBox(height: 16),
          SquadSectionLabel('TO CONFIRM', trailing: '${toConfirm.length}'),
          const SizedBox(height: 8),
          for (final settlement in toConfirm) ...[
            SquadCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name says they paid you ${formatMoney(settlement.amountCents, currency)}',
                    style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                  ),
                  Text(
                    '${settlement.method.label} · ${formatDayLabel(settlement.createdAt)}',
                    style: AppTextStyles.body(size: 12, color: squadMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _reject(context, settlement),
                        child: const Text('Not received'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => context.read<BuddyCubit>().respond(settlement.id, confirm: true),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 16),
        SquadSectionLabel('HISTORY', trailing: history.isEmpty ? null : '${history.length}'),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Text(
            'No buddy expenses with $name yet. Tap Add for something only you two shared.',
            style: AppTextStyles.body(size: 13, color: squadMuted),
          ),
        for (final entry in history) ...[entry.card, const SizedBox(height: 8)],
      ],
    );
  }

  Future<void> _reject(BuildContext context, BuddySettlement settlement) async {
    final reason = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Not received?'),
        content: TextField(
          controller: reason,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Why (optional)', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send back')),
        ],
      ),
    );
    if (send == true && context.mounted) {
      await context.read<BuddyCubit>().respond(settlement.id, confirm: false, reason: reason.text.trim());
    }
    reason.dispose();
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, required this.me, required this.ledger, required this.teamId});

  final BuddyExpense expense;
  final String me;
  final SquadLedger ledger;
  final String teamId;

  @override
  Widget build(BuildContext context) {
    final owed = expense.owedToMe(me);
    final currency = ledger.currency;
    return SquadCard(
      onTap: () => showBuddyExpenseSheet(context, teamId: teamId, me: me, editing: expense),
      child: Row(
        children: [
          Icon(categoryIcon(expense.category), color: squadMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title, style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700)),
                Text(
                  [
                    '${expense.paidBy(me) ? 'You' : ledger.nameOf(expense.payerId)} paid '
                        '${formatMoney(expense.amountCents, currency)}',
                    expense.splitMode.label,
                    formatDayLabel(expense.spentAt),
                  ].join(' · '),
                  style: AppTextStyles.body(size: 12, color: squadMuted),
                ),
                if (expense.note case final note?)
                  Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.body(size: 12, color: squadMuted)),
              ],
            ),
          ),
          Text(
            switch (owed) {
              > 0 => '+${formatMoney(owed, currency)}',
              < 0 => '−${formatMoney(-owed, currency)}',
              _ => '—',
            },
            style: AppTextStyles.body(
              size: 15,
              weight: FontWeight.w800,
              color: owed < 0 ? owedColor : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.settlement, required this.me, required this.ledger});

  final BuddySettlement settlement;
  final String me;
  final SquadLedger ledger;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final fromMe = settlement.fromId == me;
    final other = ledger.nameOf(fromMe ? settlement.toId : settlement.fromId);
    return SquadCard(
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: squadMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromMe ? 'You paid $other' : '$other paid you',
                  style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700),
                ),
                Text(
                  [
                    settlement.method.label,
                    switch (settlement.status) {
                      SettlementStatus.pending => 'waiting to be confirmed',
                      SettlementStatus.confirmed => 'confirmed',
                      SettlementStatus.rejected =>
                        'not received${settlement.rejectReason == null ? '' : ' · “${settlement.rejectReason}”'}',
                    },
                    formatDayLabel(settlement.createdAt),
                  ].join(' · '),
                  style: AppTextStyles.body(size: 12, color: squadMuted),
                ),
              ],
            ),
          ),
          if (settlement.isPending && fromMe)
            TextButton(
              onPressed: () => context.read<BuddyCubit>().cancel(settlement.id),
              child: const Text('Take back'),
            )
          else
            Text(
              formatMoney(settlement.amountCents, currency),
              style: AppTextStyles.body(
                size: 15,
                weight: FontWeight.w800,
                color: settlement.status == SettlementStatus.rejected ? squadMuted : AppColors.text,
              ),
            ),
        ],
      ),
    );
  }
}

/// The Settle tab's "BUDDIES": each squad-mate you share buddy expenses
/// with and where you stand. Nothing shows until you have one.
class BuddiesSection extends StatefulWidget {
  const BuddiesSection({super.key, required this.teamId, required this.me, required this.ledger});

  final String teamId;
  final String me;
  final SquadLedger ledger;

  @override
  State<BuddiesSection> createState() => _BuddiesSectionState();
}

class _BuddiesSectionState extends State<BuddiesSection> {
  final _cubit = sl<BuddyCubit>();

  @override
  void initState() {
    super.initState();
    _cubit.load(widget.teamId);
  }

  @override
  void didUpdateWidget(BuddiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new squad, or the squad reloaded (pulled to refresh, a change).
    if (oldWidget.teamId != widget.teamId || oldWidget.ledger != widget.ledger) {
      _cubit.load(widget.teamId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BuddyCubit, BuddyState>(
      bloc: _cubit,
      builder: (context, state) {
        final buddies = state.teamId == widget.teamId ? state.ledger : null;
        if (buddies == null || buddies.buddies.isEmpty) return const SizedBox.shrink();
        final currency = widget.ledger.currency;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            SquadSectionLabel('BUDDIES', trailing: '${buddies.buddies.length}'),
            const SizedBox(height: 8),
            for (final id in buddies.buddies) ...[
              Builder(
                builder: (context) {
                  final balance = buddies.balanceWith(id);
                  final waiting = buddies.awaitingMeFrom(id).length;
                  return SquadCard(
                    onTap: () => context.push(AppRoutes.buddy(id)),
                    child: Row(
                      children: [
                        SquadAvatar(
                          initial: widget.ledger.member(id)?.initial ?? '?',
                          size: 34,
                          photoUrl: widget.ledger.member(id)?.avatarUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.ledger.nameOf(id),
                                style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700),
                              ),
                              Text(
                                [
                                  switch (balance) {
                                    < 0 => 'You owe ${formatMoney(-balance, currency)}',
                                    > 0 => 'Owes you ${formatMoney(balance, currency)}',
                                    _ => 'All square',
                                  },
                                  if (waiting > 0) '$waiting to confirm',
                                ].join(' · '),
                                style: AppTextStyles.body(
                                  size: 12.5,
                                  color: balance < 0 ? owedColor : squadMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: squadMuted),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
