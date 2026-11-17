import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/empty_state.dart';
import '../../../../core/theme/widgets/skeletons.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../domain/entities/bill_split.dart';
import '../../domain/entities/team_wallet.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_state.dart';
import '../wallet_formatting.dart';
import '../widgets/bill_details_sheet.dart';

/// Every match bill, newest first, grouped by month — the Wallet tab's
/// "See all bills". Each shows whether it's settled or how many still owe;
/// tapping one opens its details (who's paid, slips, reminders).
class WalletBillsPage extends StatelessWidget {
  const WalletBillsPage({super.key, required this.userId, required this.isManager});

  final String userId;

  /// Manager view — the payer can edit their bill from its details only then.
  final bool isManager;

  static String _monthLabel(DateTime at) {
    final local = at.toLocal();
    return '${monthNames[local.month - 1].toUpperCase()} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('All bills', style: AppTextStyles.title(size: 16)),
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          final wallet = state.wallet;
          if (wallet == null) {
            return const SkeletonList(
              item: BillCardSkeleton(),
              padding: EdgeInsets.fromLTRB(20, 4, 20, 32),
            );
          }
          final bills = [...wallet.bills]
            ..sort((a, b) => b.$1.match.kickoffAt.compareTo(a.$1.match.kickoffAt));
          if (bills.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No bills yet',
              body: 'Match bills and payment shares will be listed here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              for (final (index, bill) in bills.indexed) ...[
                if (index == 0 ||
                    _monthLabel(bill.$1.match.kickoffAt) !=
                        _monthLabel(bills[index - 1].$1.match.kickoffAt))
                  Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 8 : 18, bottom: 10),
                    child: Text(
                      _monthLabel(bill.$1.match.kickoffAt),
                      style: AppTextStyles.label(color: AppColors.textMuted),
                    ),
                  )
                else
                  const SizedBox(height: 10),
                _BillRow(
                  walletMatch: bill.$1,
                  split: bill.$2,
                  userId: userId,
                  onTap: () => showBillDetailsSheet(
                    context,
                    matchId: bill.$1.match.id,
                    userId: userId,
                    canEdit: isManager && bill.$2.bill.payerId == userId,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.walletMatch,
    required this.split,
    required this.userId,
    required this.onTap,
  });

  final WalletMatch walletMatch;
  final BillSplit split;
  final String userId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final match = walletMatch.match;
    final bill = split.bill;
    final local = match.kickoffAt.toLocal();
    final settled = split.unpaid.isEmpty;
    final myShare = split.shareFor(userId);
    final iOwe = myShare != null && !myShare.isSettled;
    final (statusText, statusColor) = settled
        ? ('Settled', AppColors.accent2_700)
        : iOwe
            ? ('You owe ${formatBaht(split.roundedShare)}', AppColors.accent700)
            : ('${split.unpaid.length} unpaid', AppColors.accent700);
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lg,
        side: BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.neutral900,
                  borderRadius: AppRadius.md,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${local.day}',
                      style: AppTextStyles.title(size: 18, color: AppColors.teamGold),
                    ),
                    Text(
                      monthNames[local.month - 1].toUpperCase(),
                      style: AppTextStyles.body(
                        size: 10,
                        weight: FontWeight.w700,
                        color: AppColors.onDark.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${match.opponent}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title(size: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatBahtExact(bill.totalCost)} · paid by '
                      '${bill.payerId == userId ? 'you' : bill.payerName}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (settled) ...[
                      Icon(Icons.check_rounded, size: 13, color: statusColor),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      statusText,
                      style: AppTextStyles.body(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
