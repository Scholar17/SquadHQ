import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../domain/entities/bill_split.dart';
import '../../domain/entities/team_wallet.dart';
import '../wallet_formatting.dart';
import 'bill_details_sheet.dart';
import 'bill_sheet.dart';
import 'remind_unpaid_sheet.dart';

/// A match's bill at a glance — total, who paid it, the split, each
/// player's share, and how many have paid back. Shown on both the Match
/// tab and the Wallet tab; tapping it opens the full breakdown.
class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.walletMatch,
    required this.split,
    required this.userId,
    required this.isManager,
    this.showMatch = false,
  });

  final WalletMatch walletMatch;
  final BillSplit split;
  final String userId;

  /// Whether the viewer is in the Manager view. Editing a bill needs both
  /// that and being its payer — a payer in the Player view switches to
  /// Manager first.
  final bool isManager;

  /// Whether to lead with the match ("vs X · date") — the Wallet tab's
  /// list needs it; the Match tab already shows the match above.
  final bool showMatch;

  @override
  Widget build(BuildContext context) {
    final bill = split.bill;
    final match = walletMatch.match;
    final isPayer = bill.payerId == userId;
    final canEdit = isPayer && isManager;
    final myShare = split.shareFor(userId);
    final payers = split.shares.where((share) => !share.isPayer).length;
    return Material(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showBillDetailsSheet(
          context,
          matchId: match.id,
          userId: userId,
          canEdit: canEdit,
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showMatch
                          ? 'vs ${match.opponent} · ${formatMatchDate(match.kickoffAt)}'
                          : 'MATCH BILL',
                      overflow: TextOverflow.ellipsis,
                      style: showMatch
                          ? AppTextStyles.body(size: 13.5, weight: FontWeight.w800)
                          : AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                    ),
                  ),
                  if (canEdit)
                    _SmallButton(
                      label: 'Edit bill',
                      onPressed: () => showBillSheet(context, matchId: match.id, userId: userId),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatBahtExact(bill.totalCost)} total',
                          style: AppTextStyles.body(size: 13, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Paid by ${isPayer ? 'you' : bill.payerName}',
                          style: AppTextStyles.body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.text.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${splitModeLabel(bill.splitMode)} · ${split.shares.length}',
                          style: AppTextStyles.body(
                            size: 11.5,
                            color: AppColors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (split.shares.isNotEmpty) ShareAmount(split: split),
                ],
              ),
              if (payers > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: split.paid.length / payers,
                    minHeight: 6,
                    backgroundColor: AppColors.neutral300,
                    color: AppColors.accent2_700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${split.paid.length} of $payers paid back',
                  style: AppTextStyles.body(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: AppColors.text.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 4),
                // Where the money is: paid back + still owed + the payer's
                // own share (and rounding) = the total.
                Text(
                  '${formatBaht(split.collected)} paid back + '
                  '${formatBaht(split.outstanding)} owed + '
                  '${formatBaht(split.payerCovers)} ${isPayer ? 'your' : "${bill.payerName}'s"} share '
                  '= ${formatBahtExact(bill.totalCost)}',
                  style: AppTextStyles.body(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: AppColors.text.withValues(alpha: 0.55),
                  ),
                ),
                if ((isPayer || isManager) && split.unpaid.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _RemindUnpaidButton(matchId: match.id, split: split),
                ],
              ],
              if (split.shares.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  bill.splitMode == SplitMode.rsvpIn
                      ? 'No one has said In yet — shares appear as players RSVP.'
                      : 'No players in this split.',
                  style: AppTextStyles.body(
                    size: 11.5,
                    color: AppColors.text.withValues(alpha: 0.55),
                  ),
                ),
              ],
              // Just the viewer's status — paying happens only from the
              // Wallet tab's "You owe" card.
              if (myShare != null && !myShare.isPayer) ...[
                const SizedBox(height: 12),
                _MyShareStatus(paid: myShare.payment != null, amount: split.roundedShare),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MyShareStatus extends StatelessWidget {
  const _MyShareStatus({required this.paid, required this.amount});

  final bool paid;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final color = paid ? AppColors.accent2_700 : AppColors.accent700;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: paid ? AppColors.accent2_100 : AppColors.accent100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            paid ? "You've paid" : 'You owe ${formatBaht(amount)} · pay in Wallet',
            style: AppTextStyles.body(size: 12.5, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Opens "Remind unpaid" (all, or picked players) — for the payer or an
/// admin. Greys out once everyone unpaid was already reminded today.
class _RemindUnpaidButton extends StatelessWidget {
  const _RemindUnpaidButton({required this.matchId, required this.split});

  final String matchId;
  final BillSplit split;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remindable = split.unpaid
        .where((share) => !split.bill.remindedToday(share.member.profileId, now))
        .length;
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: OutlinedButton.icon(
        onPressed: remindable == 0 ? null : () => showRemindUnpaidSheet(context, matchId: matchId),
        icon: Icon(
          remindable == 0 ? Icons.check_rounded : Icons.notifications_active_rounded,
          size: 17,
        ),
        label: Text(
          remindable == 0 ? 'Everyone unpaid was reminded today' : 'Remind unpaid ($remindable)',
          style: AppTextStyles.body(size: 12.5, weight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// Shown to admins (in the Manager view) for a match with no bill yet.
class AddBillCard extends StatelessWidget {
  const AddBillCard({
    super.key,
    required this.walletMatch,
    required this.userId,
    this.showMatch = false,
  });

  final WalletMatch walletMatch;
  final String userId;
  final bool showMatch;

  @override
  Widget build(BuildContext context) {
    final match = walletMatch.match;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showMatch ? 'vs ${match.opponent}' : 'MATCH BILL',
                  style: showMatch
                      ? AppTextStyles.body(size: 13.5, weight: FontWeight.w800)
                      : AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                ),
                const SizedBox(height: 3),
                Text(
                  showMatch
                      ? '${formatMatchDate(match.kickoffAt)} · no total cost yet'
                      : 'Paid for the pitch? Add the total cost to split it.',
                  style: AppTextStyles.body(
                    size: 12,
                    color: AppColors.text.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SmallButton(
            label: 'Add total cost',
            onPressed: () => showBillSheet(context, matchId: match.id, userId: userId),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        minimumSize: const Size(0, 30),
      ),
      child: Text(label, style: AppTextStyles.heading(size: 12)),
    );
  }
}
