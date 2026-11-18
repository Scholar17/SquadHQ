import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../personal/presentation/personal_formatting.dart' show formatDayLabel;
import '../../../squad/domain/entities/expense.dart' show ExpenseCategory;
import '../../../squad/domain/entities/settlement.dart' show SettlementStatus;
import '../../../squad/domain/entities/squad_ledger.dart';
import '../../../squad/presentation/squad_formatting.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../../team_membership/domain/entities/team.dart' show GroupCurrency;
import '../../domain/entities/buddy.dart';
import '../cubit/buddy_cubit.dart';
import 'buddy_expense_sheet.dart';

/// The rounded icon tile a history row leads with.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.background, required this.foreground});

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.sm),
      child: Icon(icon, size: 20, color: foreground),
    );
  }
}

/// What a row means for you, right-aligned: a small caption over the
/// amount — "you lent ฿150", "you owe ฿700".
class _Outcome extends StatelessWidget {
  const _Outcome({required this.caption, required this.amount, required this.color});

  final String caption;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(caption, style: AppTextStyles.body(size: 11, color: squadMuted, height: 1.3)),
        Text(
          amount,
          style: AppTextStyles.body(size: 14, weight: FontWeight.w800, color: color, height: 1.3),
        ),
      ],
    );
  }
}

/// One buddy expense: its category, who paid what, and where it leaves
/// you. Tap to edit.
class BuddyExpenseTile extends StatelessWidget {
  const BuddyExpenseTile({
    super.key,
    required this.expense,
    required this.me,
    required this.ledger,
    required this.teamId,
  });

  final BuddyExpense expense;
  final String me;
  final SquadLedger ledger;
  final String teamId;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final owed = expense.owedToMe(me);
    final tone = categoryTone(expense.category);
    final category = expense.category == ExpenseCategory.other
        ? expense.categoryLabel ?? expense.category.label
        : expense.category.label;
    final (caption, amount, color) = switch (owed) {
      > 0 => ('you lent', formatMoney(owed, currency), owedColor),
      < 0 => ('you owe', formatMoney(-owed, currency), oweColor),
      _ => ('even', '—', squadMuted),
    };
    return SquadCard(
      onTap: () => showBuddyExpenseSheet(context, teamId: teamId, me: me, editing: expense),
      child: Row(
        children: [
          _IconTile(
            icon: categoryIcon(expense.category),
            background: tone.background,
            foreground: tone.foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(size: 15, height: 1.3),
                ),
                Text(
                  [
                    category,
                    '${expense.paidBy(me) ? 'You' : ledger.nameOf(expense.payerId)} paid '
                        '${formatMoney(expense.amountCents, currency)}',
                    expense.splitMode.label,
                    formatDayLabel(expense.spentAt),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                ),
                if (expense.note case final note? when note.trim().isNotEmpty)
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Outcome(caption: caption, amount: amount, color: color),
        ],
      ),
    );
  }
}

/// One payment between you: who paid whom, how, and where it stands —
/// with "Take back" while yours is still waiting.
class BuddyPaymentTile extends StatelessWidget {
  const BuddyPaymentTile({super.key, required this.settlement, required this.me, required this.ledger});

  final BuddySettlement settlement;
  final String me;
  final SquadLedger ledger;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final fromMe = settlement.fromId == me;
    final other = ledger.nameOf(fromMe ? settlement.toId : settlement.fromId);
    final rejected = settlement.status == SettlementStatus.rejected;
    final status = switch (settlement.status) {
      SettlementStatus.pending => 'waiting to be confirmed',
      SettlementStatus.confirmed => 'confirmed',
      SettlementStatus.rejected =>
        'not received${settlement.rejectReason == null ? '' : ' · “${settlement.rejectReason}”'}',
    };
    return SquadCard(
      child: Row(
        children: [
          _IconTile(
            icon: Icons.swap_horiz_rounded,
            background: rejected ? AppColors.neutral200 : AppColors.accent2_100,
            foreground: rejected ? AppColors.neutral700 : AppColors.accent2_700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromMe ? 'You paid $other' : '$other paid you',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(size: 15, height: 1.3),
                ),
                Text(
                  [settlement.method.label, status, formatDayLabel(settlement.createdAt)].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (settlement.isPending && fromMe)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(settlement.amountCents, currency),
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w800, height: 1.3),
                ),
                TextButton(
                  onPressed: () => context.read<BuddyCubit>().cancel(settlement.id),
                  style: TextButton.styleFrom(
                    foregroundColor: oweColor,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Take back'),
                ),
              ],
            )
          else
            Text(
              formatMoney(settlement.amountCents, currency),
              style: AppTextStyles.body(
                size: 14,
                weight: FontWeight.w800,
                color: rejected ? squadMuted : AppColors.text,
              ).copyWith(decoration: rejected ? TextDecoration.lineThrough : null),
            ),
        ],
      ),
    );
  }
}

/// A payment [name] says they sent you, waiting for you: highlighted like
/// the squad's "needs your check", with Not received and Confirm.
class BuddyConfirmCard extends StatelessWidget {
  const BuddyConfirmCard({
    super.key,
    required this.settlement,
    required this.name,
    required this.currency,
    required this.onReject,
    required this.onConfirm,
  });

  final BuddySettlement settlement;
  final String name;
  final GroupCurrency currency;
  final VoidCallback onReject;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.accent100,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.accent400, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEEDS YOUR CHECK', style: AppTextStyles.label(color: AppColors.unread)),
          const SizedBox(height: 2),
          Text(
            '$name says they paid you ${formatMoney(settlement.amountCents, currency)}',
            style: AppTextStyles.body(size: 14, weight: FontWeight.w700, height: 1.3),
          ),
          Text(
            '${settlement.method.label} · ${formatDayLabel(settlement.createdAt)}',
            style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: onReject,
                style: TextButton.styleFrom(foregroundColor: AppColors.text),
                child: const Text('Not received'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.unread,
                  foregroundColor: AppColors.onDark,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
