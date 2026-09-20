import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team_snapshot.dart';
import '../bloc/team_bloc.dart';
import '../bloc/team_state.dart';
import '../widgets/add_bill_sheet.dart';
import '../widgets/pay_qr_sheet.dart';

/// Team balance, match fees, and the Thai QR payment flow.
class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  void _snack(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: BlocBuilder<TeamBloc, TeamState>(
          builder: (context, state) {
            if (state is! TeamLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }
            final snapshot = state.snapshot;
            final myDue = snapshot.owing.isNotEmpty ? snapshot.owing.first : null;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  'SQUAD WALLET',
                  style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                ),
                const SizedBox(height: 12),
                _LedgerCard(
                  balance: snapshot.teamBalance,
                  monthIn: snapshot.monthIn,
                  monthOut: snapshot.monthOut,
                  monthNet: snapshot.monthNet,
                ),
                if (!state.isManager && myDue != null) ...[
                  const SizedBox(height: 14),
                  _MyBalanceCard(
                    amount: '฿${myDue.amountOwed.toStringAsFixed(0)}',
                    note: "For last Sunday's match",
                    onPay: () => showPayQrSheet(
                      context,
                      amount: '฿${myDue.amountOwed.toStringAsFixed(0)}',
                      note: "For last Sunday's match",
                    ),
                  ),
                ],
                if (state.isManager) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'MATCH FEES',
                          style: AppTextStyles.label(
                            color: AppColors.text.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      Text(
                        '${snapshot.owing.length} unpaid',
                        style: AppTextStyles.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AppColors.accent700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => showAddBillSheet(context, roster: snapshot.roster),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent700,
                          side: BorderSide(color: AppColors.accent700.withValues(alpha: 0.35)),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          minimumSize: const Size(0, 30),
                        ),
                        child: Text('+ Add bill', style: AppTextStyles.heading(size: 12, color: AppColors.accent700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < snapshot.owing.length; i++)
                          _OwingRow(
                            member: snapshot.owing[i],
                            showTopBorder: i > 0,
                            onRequest: () => _snack(context, 'Payment request'),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'RECENT ACTIVITY',
                  style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < snapshot.ledger.length; i++)
                        _LedgerRow(entry: snapshot.ledger[i], showTopBorder: i > 0),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.balance,
    required this.monthIn,
    required this.monthOut,
    required this.monthNet,
  });

  final String balance;
  final String monthIn;
  final String monthOut;
  final String monthNet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team balance',
            style: AppTextStyles.body(
              size: 12,
              weight: FontWeight.w500,
              color: AppColors.neutral100.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(balance, style: AppTextStyles.heading(size: 40, color: AppColors.teamGold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x24F9F4ED))),
            ),
            child: Row(
              children: [
                _MiniStat(value: monthIn, label: 'In · August'),
                const SizedBox(width: 18),
                _MiniStat(value: monthOut, label: 'Out · August'),
                const SizedBox(width: 18),
                _MiniStat(value: monthNet, label: 'Net', color: AppColors.accent2_100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.body(
            size: 13,
            weight: FontWeight.w700,
            color: color ?? AppColors.neutral100,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTextStyles.body(
            size: 11,
            weight: FontWeight.w500,
            color: AppColors.neutral100.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _MyBalanceCard extends StatelessWidget {
  const _MyBalanceCard({
    required this.amount,
    required this.note,
    required this.onPay,
  });

  final String amount;
  final String note;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accent100,
        border: Border.all(color: AppColors.accent700.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR BALANCE',
                  style: AppTextStyles.label(color: AppColors.accent800),
                ),
                const SizedBox(height: 10),
                Text(amount, style: AppTextStyles.heading(size: 30, color: AppColors.accent900)),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: AppTextStyles.body(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: AppColors.accent800,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onPay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bg,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Pay via QR', style: AppTextStyles.heading(size: 13, color: AppColors.bg)),
          ),
        ],
      ),
    );
  }
}

class _OwingRow extends StatelessWidget {
  const _OwingRow({
    required this.member,
    required this.showTopBorder,
    required this.onRequest,
  });

  final SquadMember member;
  final bool showTopBorder;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showTopBorder
            ? Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.07)))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: AppTextStyles.body(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Match fee outstanding',
                  style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.text.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '฿${member.amountOwed.toStringAsFixed(0)}',
            style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: AppColors.accent700),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onRequest,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 30),
            ),
            child: Text('Request', style: AppTextStyles.heading(size: 12)),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.showTopBorder});

  final LedgerEntry entry;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showTopBorder
            ? Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.07)))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: AppTextStyles.body(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  entry.meta,
                  style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.text.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            entry.amount,
            style: AppTextStyles.body(
              size: 13,
              weight: FontWeight.w700,
              color: entry.isCredit ? AppColors.accent2_700 : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
