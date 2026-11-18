import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/skeletons.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../squad/domain/entities/squad_ledger.dart';
import '../../../squad/presentation/active_group.dart';
import '../../../squad/presentation/bloc/squad_ledger_bloc.dart';
import '../../../squad/presentation/squad_formatting.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../domain/entities/buddy.dart';
import '../cubit/buddy_cubit.dart';
import '../widgets/buddy_expense_sheet.dart';
import '../widgets/buddy_history.dart';
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
    final squadState = context.watch<SquadLedgerBloc>().state;
    final ledger = squadState.ledger;
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
            body: squad == null || ledger == null
                // The squad itself isn't in yet (or failed): its own view.
                ? SquadLoadingView(state: squadState)
                : buddies == null
                ? const SkeletonList(item: ExpenseRowSkeleton(), count: 6, spacing: 8)
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
    final name = ledger.nameOf(buddyId);
    final toConfirm = buddies.awaitingMeFrom(buddyId);
    // Newest first: expenses and payments together.
    final history = <({DateTime at, Widget tile})>[
      for (final expense in buddies.expensesWith(buddyId))
        (
          at: expense.spentAt,
          tile: BuddyExpenseTile(expense: expense, me: me, ledger: ledger, teamId: teamId),
        ),
      for (final settlement in buddies.settlementsWith(buddyId))
        (
          at: settlement.createdAt,
          tile: BuddyPaymentTile(settlement: settlement, me: me, ledger: ledger),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return ListView(
      // Room under the last row for the Add button.
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      children: [
        _BalanceHero(teamId: teamId, me: me, buddyId: buddyId, ledger: ledger, buddies: buddies),
        if (toConfirm.isNotEmpty) ...[
          const SizedBox(height: 20),
          SquadSectionLabel('TO CONFIRM', trailing: '${toConfirm.length}'),
          const SizedBox(height: 8),
          for (final settlement in toConfirm) ...[
            BuddyConfirmCard(
              settlement: settlement,
              name: name,
              currency: ledger.currency,
              onReject: () => _reject(context, settlement),
              onConfirm: () => context.read<BuddyCubit>().respond(settlement.id, confirm: true),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 20),
        SquadSectionLabel('HISTORY', trailing: history.isEmpty ? null : '${history.length}'),
        const SizedBox(height: 8),
        if (history.isEmpty)
          _EmptyHistory(name: name)
        else
          SeeMoreList(previewCount: 10, children: [for (final entry in history) entry.tile]),
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

/// Where you stand with [buddyId], on the dark hero: who pays whom and how
/// much, what you've sent that's still waiting, and the one action — "I
/// paid" or "Mark as received".
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
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
    final member = ledger.member(buddyId);
    final balance = buddies.balanceWith(buddyId);
    final sent = [
      for (final s in buddies.settlementsWith(buddyId))
        if (s.isPending && s.fromId == me) s.amountCents,
    ].fold(0, (total, cents) => total + cents);
    const light = AppColors.onDark;
    return DarkHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SquadAvatar(
                initial: member?.initial ?? '?',
                photoUrl: member?.avatarUrl,
                size: 28,
                color: AppColors.teamGold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  switch (balance) {
                    < 0 => 'YOU PAY ${name.toUpperCase()}',
                    > 0 => '${name.toUpperCase()} PAYS YOU',
                    _ => 'ALL SQUARE WITH ${name.toUpperCase()}',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(color: AppColors.teamGold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(balance.abs(), currency),
            key: const ValueKey('buddy-balance'),
            style: AppTextStyles.heading(size: 34, color: AppColors.teamGold, height: 1.15),
          ),
          const SizedBox(height: 4),
          Text(
            'Just between you two · not in the squad balance',
            style: AppTextStyles.body(size: 12.5, color: light.withValues(alpha: 0.85)),
          ),
          if (sent > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: light.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You sent ${formatMoney(sent, currency)} · waiting for $name to confirm',
                    style: AppTextStyles.body(size: 12.5, color: light.withValues(alpha: 0.85)),
                  ),
                ),
              ],
            ),
          ],
          if (balance != 0) ...[
            const SizedBox(height: 16),
            HeroPillButton(
              label: balance < 0 ? 'I paid ${formatMoney(-balance, currency)}' : 'Mark as received',
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
    );
  }
}

/// Nothing between you yet: what buddy expenses are for.
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return SquadCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Icon(Icons.handshake_outlined, size: 20, color: squadMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No buddy expenses with $name yet. Tap Add for something only you two shared.',
              style: AppTextStyles.body(size: 13, color: squadMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
