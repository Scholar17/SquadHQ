import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
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
import '../widgets/squad_widgets.dart';

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
            if (squad == null || ledger == null) {
              return const Center(child: CircularProgressIndicator(color: AppColors.accent));
            }
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
                      extra: NotificationsArgs(userId: me, adminViewIsManager: true),
                    ),
                    onProfileTap: () => context.push(AppRoutes.profile, extra: user),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BalanceHero(
                          ledger: ledger,
                          me: me,
                          onSettle: () => context.go(AppRoutes.wallet),
                          onAdd: () => showExpenseSheet(context, teamId: squad.id, me: me),
                        ),
                        for (final settlement in ledger.awaitingConfirmationBy(me)) ...[
                          const SizedBox(height: 12),
                          _ConfirmBanner(
                            text:
                                '${ledger.nameOf(settlement.fromId)} says they paid you '
                                '${formatMoney(settlement.amountCents, ledger.currency)}',
                            onTap: () => showConfirmPaymentSheet(context, settlement: settlement),
                          ),
                        ],
                        const SizedBox(height: 20),
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
  });

  final SquadLedger ledger;
  final String me;
  final VoidCallback onSettle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final balance = ledger.balanceOf(me);
    final debts = ledger.simplifiedDebts;
    final myDebts = debts.where((debt) => debt.fromId == me).toList();
    final owedBy = debts.where((debt) => debt.toId == me).length;
    final pending = ledger.pendingFrom(me);
    final headline = switch (balance) {
      < 0 when myDebts.length == 1 => 'You owe ${ledger.nameOf(myDebts.single.toId)}',
      < 0 => 'You owe ${myDebts.length} people',
      > 0 => "You're owed",
      _ => "You're all square",
    };
    final detail = [
      if (balance > 0 && owedBy > 0) 'by $owedBy ${owedBy == 1 ? 'person' : 'people'}',
      if (balance < 0) 'after simplifying',
      if (pending.isNotEmpty)
        '${formatMoney(pending.fold(0, (sum, s) => sum + s.amountCents), currency)} '
            'waiting for ${pending.length == 1 ? ledger.nameOf(pending.single.toId) : 'others'} '
            'to confirm',
    ].join(' · ');
    const light = AppColors.neutral100;
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
              color: light.withValues(alpha: 0.75),
            ),
          ),
          Text(
            formatMoney(balance.abs(), currency),
            style: AppTextStyles.heading(size: 40, color: AppColors.teamGold),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(detail, style: AppTextStyles.body(size: 12, color: light.withValues(alpha: 0.7))),
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
        ],
      ),
    );
  }
}

class _ConfirmBanner extends StatelessWidget {
  const _ConfirmBanner({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, size: 20, color: oweColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600)),
              ),
              Text(
                'Check',
                style: AppTextStyles.body(size: 13, weight: FontWeight.w800, color: oweColor),
              ),
            ],
          ),
        ),
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
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text('No expenses yet', style: AppTextStyles.heading(size: 18)),
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
