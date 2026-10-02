import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../team_membership/domain/entities/team.dart' as membership;
import '../../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_state.dart';
import '../../../wallet/domain/entities/bill_split.dart';
import '../../../wallet/domain/entities/team_wallet.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../wallet/presentation/wallet_formatting.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../../wallet/presentation/widgets/bill_details_sheet.dart';
import '../../../wallet/presentation/widgets/bill_sheet.dart';
import '../../../wallet/presentation/widgets/bill_card.dart';
import '../../../wallet/presentation/widgets/pay_bill_sheet.dart';
import '../../domain/entities/team_snapshot.dart' show SquadRole;
import '../bloc/team_bloc.dart';
import '../view_role.dart';

/// The team's match bills: what's still owed to whoever paid, what you
/// owe, and every bill's split. Backed by supabase/sql/008. The same bills
/// show on the Match tab — both read the app-root [WalletBloc].
class WalletPage extends StatelessWidget {
  const WalletPage({super.key, required this.user});

  final AppUser user;

  static membership.Team? _activeTeam(TeamMembershipState state) {
    final settled = switch (state) {
      TeamMembershipSubmitting(:final previous) => previous,
      TeamMembershipFailure(:final previous) => previous,
      _ => state,
    };
    if (settled is! TeamMembershipLoaded) return null;
    for (final team in settled.teams) {
      if (team.isActive) return team;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: BlocBuilder<TeamMembershipBloc, TeamMembershipState>(
          builder: (context, membershipState) {
            final active = _activeTeam(membershipState);
            if (active == null) {
              return _EmptyWallet(
                title: "You're not on a team yet",
                body: 'Create or join a team to split match costs here.',
                actionLabel: 'Create or join a team',
                onAction: () => context.push(AppRoutes.team),
              );
            }
            final isManager =
                viewRoleFor(active.role, context.watch<TeamBloc>().state) == SquadRole.manager;
            return BlocBuilder<WalletBloc, WalletState>(
              builder: (context, state) {
                final wallet = state.wallet;
                if (wallet == null) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                }
                return RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () {
                    final done = Completer<void>();
                    context.read<WalletBloc>().add(WalletRefreshRequested(done: done));
                    return done.future;
                  },
                  child: _WalletContent(wallet: wallet, userId: user.id, isManager: isManager),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WalletContent extends StatelessWidget {
  const _WalletContent({required this.wallet, required this.userId, required this.isManager});

  final TeamWallet wallet;
  final String userId;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    final bills = wallet.bills;
    final owed = wallet.owedBy(userId);
    final unbilled = [
      for (final walletMatch in wallet.matches)
        if (walletMatch.bill == null) walletMatch,
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text('Wallet', style: AppTextStyles.heading(size: 22))),
            IconButton(
              onPressed: () => context.push(
                AppRoutes.walletBills,
                extra: WalletBillsArgs(userId: userId, isManager: isManager),
              ),
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Bill history',
              color: AppColors.text,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_focusMatch(wallet) case final focus?)
          _FocusBillCard(
            walletMatch: focus,
            split: wallet.splitFor(focus),
            userId: userId,
            isManager: isManager,
          ),
        if (owed.isNotEmpty) ...[
          const SizedBox(height: 14),
          _YourBalanceCard(owed: owed, userId: userId),
        ],
        const SizedBox(height: 20),
        _SectionLabel('MATCH BILLS', trailing: bills.isEmpty ? null : '${bills.length}'),
        const SizedBox(height: 10),
        if (bills.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isManager
                  ? 'No bills yet. Paid for a pitch? Add its total cost below and '
                        'it splits automatically.'
                  : "No bills yet. When an admin pays for a match, your share shows up here.",
              style: AppTextStyles.body(
                size: 12.5,
                color: AppColors.text.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          )
        else ...[
          // The few that matter most — anything still owed first, then
          // newest; the rest are behind "See all bills".
          for (final (walletMatch, split) in _topBills(bills)) ...[
            BillCard(
              walletMatch: walletMatch,
              split: split,
              userId: userId,
              isManager: isManager,
              showMatch: true,
            ),
            const SizedBox(height: 10),
          ],
          if (bills.length > _topBillCount)
            Center(
              child: TextButton(
                onPressed: () => context.push(
                  AppRoutes.walletBills,
                  extra: WalletBillsArgs(userId: userId, isManager: isManager),
                ),
                child: Text(
                  'See all bills (${bills.length})',
                  style: AppTextStyles.heading(size: 13, color: AppColors.accent700),
                ),
              ),
            ),
        ],
        if (isManager && unbilled.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionLabel('NO TOTAL COST YET', trailing: '${unbilled.length}'),
          const SizedBox(height: 10),
          _UnbilledList(unbilled: unbilled, userId: userId),
        ],
      ],
    );
  }
}

/// "No total cost yet" matches — the first [_previewCount], with "See more"
/// expanding the rest in place (there's no separate page for them).
class _UnbilledList extends StatefulWidget {
  const _UnbilledList({required this.unbilled, required this.userId});

  final List<WalletMatch> unbilled;
  final String userId;

  static const _previewCount = 2;

  @override
  State<_UnbilledList> createState() => _UnbilledListState();
}

class _UnbilledListState extends State<_UnbilledList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final unbilled = widget.unbilled;
    final hasMore = unbilled.length > _UnbilledList._previewCount;
    final shown = _expanded ? unbilled : unbilled.take(_UnbilledList._previewCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final walletMatch in shown) ...[
          AddBillCard(walletMatch: walletMatch, userId: widget.userId, showMatch: true),
          const SizedBox(height: 10),
        ],
        if (hasMore)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? 'Show less'
                    : 'See more (${unbilled.length - _UnbilledList._previewCount})',
                style: AppTextStyles.heading(size: 13, color: AppColors.accent700),
              ),
            ),
          ),
      ],
    );
  }
}

const _topBillCount = 2;

/// Bills still owed on first (newest first), then settled ones — capped.
List<(WalletMatch, BillSplit)> _topBills(List<(WalletMatch, BillSplit)> bills) {
  final sorted = [...bills]
    ..sort((a, b) {
      final aOpen = a.$2.outstanding > 0 ? 0 : 1;
      final bOpen = b.$2.outstanding > 0 ? 0 : 1;
      if (aOpen != bOpen) return aOpen - bOpen;
      return b.$1.match.kickoffAt.compareTo(a.$1.match.kickoffAt);
    });
  return sorted.take(_topBillCount).toList();
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
          ),
        ),
        if (trailing != null)
          Text(trailing, style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.4))),
      ],
    );
  }
}

/// The match the Wallet leads with: today's (the soonest, if several),
/// otherwise the one closest to now — preferring matches with a bill.
WalletMatch? _focusMatch(TeamWallet wallet) {
  final billed = [
    for (final walletMatch in wallet.matches)
      if (walletMatch.bill != null) walletMatch,
  ];
  final pool = billed.isNotEmpty ? billed : wallet.matches;
  if (pool.isEmpty) return null;
  final now = DateTime.now();
  bool isToday(WalletMatch walletMatch) {
    final at = walletMatch.match.kickoffAt.toLocal();
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }

  final today = pool.where(isToday).toList()
    ..sort((a, b) => a.match.kickoffAt.compareTo(b.match.kickoffAt));
  if (today.isNotEmpty) return today.first;
  return pool.reduce(
    (a, b) =>
        a.match.kickoffAt.difference(now).abs() <= b.match.kickoffAt.difference(now).abs() ? a : b,
  );
}

/// The Wallet's first card: one match's money — today's match, or the
/// closest to today. How much is still owed, and where the total stands
/// (paid back + owed + the payer's own share). Tap for the bill's details.
class _FocusBillCard extends StatelessWidget {
  const _FocusBillCard({
    required this.walletMatch,
    required this.split,
    required this.userId,
    required this.isManager,
  });

  final WalletMatch walletMatch;
  final BillSplit? split;
  final String userId;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    final match = walletMatch.match;
    final local = match.kickoffAt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final muted = AppColors.neutral100.withValues(alpha: 0.6);
    final split = this.split;
    final bill = split?.bill;
    final isPayer = bill?.payerId == userId;
    return Material(
      color: AppColors.neutral900,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: split == null
            ? null
            : () => showBillDetailsSheet(
                context,
                matchId: match.id,
                userId: userId,
                canEdit: isManager && isPayer,
              ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday
                    ? 'TODAY · ${formatMatchTime(match.kickoffAt)}'
                    : formatMatchDateTime(match.kickoffAt).toUpperCase(),
                style: AppTextStyles.label(color: AppColors.teamGold),
              ),
              const SizedBox(height: 6),
              Text(
                'vs ${match.opponent}',
                style: AppTextStyles.heading(size: 18, color: AppColors.neutral100),
              ),
              const SizedBox(height: 12),
              if (split == null || bill == null) ...[
                Text(
                  'No total cost yet',
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: muted),
                ),
                if (isManager) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => showBillSheet(context, matchId: match.id, userId: userId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutral100,
                      side: const BorderSide(color: Color(0x47F9F4ED)),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Add total cost',
                      style: AppTextStyles.heading(size: 12.5, color: AppColors.neutral100),
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  split.outstanding > 0
                      ? 'Still owed to ${isPayer ? 'you' : bill.payerName}'
                      : 'All paid back',
                  style: AppTextStyles.body(size: 12, weight: FontWeight.w500, color: muted),
                ),
                const SizedBox(height: 4),
                Text(
                  split.outstanding > 0 ? formatBaht(split.outstanding) : 'Settled ✓',
                  style: AppTextStyles.heading(size: 36, color: AppColors.teamGold),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.only(top: 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x24F9F4ED))),
                  ),
                  child: _MoneyBreakdown(
                    paidBack: split.collected.toDouble(),
                    owed: split.outstanding.toDouble(),
                    payerCovers: split.payerCovers,
                    payerLabel: isPayer ? 'Your own share' : "${bill.payerName}'s own share",
                    total: bill.totalCost,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a bill's money is: paid back + still owed + what the payer
/// covered themselves (their own share, plus rounding) = the total — as a
/// stacked bar and the sum written out.
class _MoneyBreakdown extends StatelessWidget {
  const _MoneyBreakdown({
    required this.paidBack,
    required this.owed,
    required this.payerCovers,
    required this.payerLabel,
    required this.total,
  });

  final double paidBack;
  final double owed;
  final double payerCovers;
  final String payerLabel;
  final double total;

  static const _paidColor = AppColors.accent2_100;
  static const _owedColor = AppColors.accent400;
  static const _payersColor = AppColors.teamGold;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (label: 'Paid back', amount: paidBack, color: _paidColor),
      (label: 'Still owed', amount: owed, color: _owedColor),
      (label: payerLabel, amount: payerCovers, color: _payersColor),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (final part in parts)
                    if (part.amount > 0)
                      Expanded(
                        flex: (part.amount * 100).round(),
                        child: ColoredBox(color: part.color),
                      ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        for (final (index, part) in parts.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    index == 0 ? '' : '+',
                    style: AppTextStyles.body(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: AppColors.neutral100.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: part.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    part.label,
                    style: AppTextStyles.body(
                      size: 12.5,
                      weight: FontWeight.w500,
                      color: AppColors.neutral100.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Text(
                  formatBaht(part.amount),
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.neutral100,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x24F9F4ED))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                child: Text(
                  '=',
                  style: AppTextStyles.body(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: AppColors.neutral100.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Total',
                  style: AppTextStyles.body(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: AppColors.neutral100,
                  ),
                ),
              ),
              Text(
                formatBahtExact(total),
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w800,
                  color: AppColors.teamGold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _YourBalanceCard extends StatelessWidget {
  const _YourBalanceCard({required this.owed, required this.userId});

  final List<(WalletMatch, BillSplit)> owed;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final total = owed.fold(0, (sum, bill) => sum + bill.$2.roundedShare);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accent100,
        border: Border.all(color: AppColors.accent700.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOU OWE', style: AppTextStyles.label(color: AppColors.accent800)),
          const SizedBox(height: 8),
          Text(
            formatBaht(total),
            style: AppTextStyles.heading(size: 30, color: AppColors.accent900),
          ),
          const SizedBox(height: 6),
          for (final (walletMatch, split) in owed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'vs ${walletMatch.match.opponent} · to ${split.bill.payerName}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.accent800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        showPayBillSheet(context, matchId: walletMatch.match.id, userId: userId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bg,
                      shape: const StadiumBorder(),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 34),
                    ),
                    child: Text(
                      'Pay ${formatBaht(split.roundedShare)}',
                      style: AppTextStyles.heading(size: 12.5, color: AppColors.bg),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.teamGold, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.neutral800,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.heading(size: 20)),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                size: 13.5,
                color: AppColors.text.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel,
                  style: AppTextStyles.heading(size: 14, color: AppColors.bg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
