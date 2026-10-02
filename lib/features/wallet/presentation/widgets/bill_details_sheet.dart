import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../domain/entities/bill_split.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_state.dart';
import '../wallet_formatting.dart';
import 'bill_sheet.dart';
import 'wallet_image.dart';

/// Everyone in a bill's split and whether they've paid back. The payer
/// can open each teammate's payment slip; everyone else only their own
/// (the payment-slips storage policies enforce the same). [canEdit] is
/// true only for the payer in the Manager view.
Future<void> showBillDetailsSheet(
  BuildContext context, {
  required String matchId,
  required String userId,
  required bool canEdit,
}) {
  // The screen behind the sheet — still around after the sheet closes, so
  // "Edit bill" can open from it (the bill form first checks the payer's
  // wallet QR, which takes a moment).
  final hostContext = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        final wallet = state.wallet;
        final walletMatch = wallet?.forMatch(matchId);
        final split = walletMatch == null ? null : wallet?.splitFor(walletMatch);
        if (walletMatch == null || split == null) {
          return const SizedBox(height: 120);
        }
        final bill = split.bill;
        final isPayer = bill.payerId == userId;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            children: [
              Text('vs ${walletMatch.match.opponent}', style: AppTextStyles.heading(size: 20)),
              const SizedBox(height: 4),
              Text(
                '${formatMatchDateTime(walletMatch.match.kickoffAt)} · '
                'paid by ${isPayer ? 'you' : bill.payerName}',
                style: AppTextStyles.body(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: AppColors.text.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatBahtExact(bill.totalCost),
                          style: AppTextStyles.heading(size: 26),
                        ),
                        Text(
                          '${splitModeLabel(bill.splitMode)} · ${split.shares.length}',
                          style: AppTextStyles.body(
                            size: 12,
                            color: AppColors.text.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (split.shares.isNotEmpty) ShareAmount(split: split, size: 22),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < split.shares.length; i++)
                      _ShareRow(
                        share: split.shares[i],
                        isMe: split.shares[i].member.profileId == userId,
                        canViewSlip: isPayer || split.shares[i].member.profileId == userId,
                        showTopBorder: i > 0,
                      ),
                    if (split.shares.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No players in this split yet.',
                          style: AppTextStyles.body(
                            size: 12.5,
                            color: AppColors.text.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (canEdit) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showBillSheet(hostContext, matchId: matchId, userId: userId);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('Edit bill', style: AppTextStyles.heading(size: 14)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.share,
    required this.isMe,
    required this.canViewSlip,
    required this.showTopBorder,
  });

  final BillShare share;
  final bool isMe;
  final bool canViewSlip;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final payment = share.payment;
    final (label, color) = switch (share) {
      BillShare(isPayer: true) => ('Paid the bill', AppColors.accent2_700),
      BillShare(payment: final payment?) =>
        ('Paid ${formatMatchDate(payment.paidAt)}', AppColors.accent2_700),
      _ => ('Not paid yet', AppColors.accent700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showTopBorder
            ? Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.07)))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            share.isSettled ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${share.member.name} (you)' : share.member.name,
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          if (payment != null && canViewSlip)
            TextButton(
              onPressed: () => showWalletImageViewer(
                context,
                kind: WalletImageKind.paymentSlip,
                path: payment.slipPath,
                title: "${share.member.name}'s payment slip",
              ),
              child: Text('View slip', style: AppTextStyles.heading(size: 12)),
            ),
        ],
      ),
    );
  }
}
