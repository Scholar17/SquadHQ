import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../team_membership/domain/entities/team.dart';
import '../../domain/entities/squad_member.dart';
import '../active_group.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import '../widgets/squad_widgets.dart';

/// A squad's Members tab: your profile (and whether friends can pay you),
/// the invite code, and everyone's role and balance.
class SquadMembersPage extends StatelessWidget {
  const SquadMembersPage({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final squad = watchActiveGroup(context);
    final me = user.id;
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
            final balances = ledger.balances;
            final members = [...ledger.members]
              ..sort((a, b) => (balances[b.profileId] ?? 0).compareTo(balances[a.profileId] ?? 0));
            final mine = ledger.member(me);
            return RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => refreshSquad(context),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text('Members', style: AppTextStyles.heading(size: 24)),
                  const SizedBox(height: 14),
                  SquadCard(
                    radius: 20,
                    padding: const EdgeInsets.all(14),
                    onTap: () => context.push(AppRoutes.profile, extra: user),
                    child: Row(
                      children: [
                        SquadAvatar(
                          initial: mine?.initial ?? '?',
                          size: 48,
                          color: AppColors.accent300,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your profile',
                                style: AppTextStyles.heading(size: 16, height: 1.3),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _Chip(
                                    mine?.hasQr == true ? 'QR added' : 'No QR yet',
                                    ok: mine?.hasQr == true,
                                  ),
                                  _Chip(
                                    mine?.hasBankDetails == true
                                        ? 'Bank details added'
                                        : 'No bank details',
                                    ok: mine?.hasBankDetails == true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: squadMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
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
                              Text('INVITE CODE', style: AppTextStyles.label(color: squadMuted)),
                              SelectableText(
                                squad.inviteCode,
                                style: AppTextStyles.heading(size: 26).copyWith(letterSpacing: 3),
                              ),
                              Text(
                                'Friends join ${squad.name} with this code',
                                style: AppTextStyles.body(size: 12, color: squadMuted),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: squad.inviteCode));
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(content: Text('Invite code copied')));
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(
                            'Copy',
                            style: AppTextStyles.heading(size: 13, color: AppColors.neutral100),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.neutral900,
                            minimumSize: const Size(0, 44),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SquadSectionLabel(
                    '${members.length} ${members.length == 1 ? 'MEMBER' : 'MEMBERS'}',
                    trailing: 'BALANCE',
                  ),
                  const SizedBox(height: 8),
                  for (final member in members) ...[
                    _MemberRow(
                      member: member,
                      isMe: member.profileId == me,
                      balance: balances[member.profileId] ?? 0,
                      money: (cents) => formatMoney(cents, ledger.currency),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.ok});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: ok ? AppColors.accent2_100 : AppColors.accent100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.body(
          size: 11.5,
          weight: FontWeight.w800,
          color: ok ? owedColor : oweColor,
          height: 1.3,
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.balance,
    required this.money,
  });

  final SquadMember member;
  final bool isMe;
  final int balance;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (balance) {
      > 0 => (isMe ? "you're owed" : 'is owed', owedColor),
      < 0 => (isMe ? 'you owe' : 'owes', oweColor),
      _ => ('settled up', squadMuted),
    };
    return SquadCard(
      child: Row(
        children: [
          SquadAvatar(
            initial: member.initial,
            color: isMe
                ? AppColors.accent300
                : member.role == TeamRole.superAdmin
                ? AppColors.teamGold
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? 'You' : member.name,
                  style: AppTextStyles.heading(size: 15, height: 1.3),
                ),
                Text(
                  member.roleLabel,
                  style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.3),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label, style: AppTextStyles.body(size: 11, color: squadMuted, height: 1.3)),
              Text(
                money(balance.abs()),
                style: AppTextStyles.body(
                  size: 14,
                  weight: FontWeight.w800,
                  color: color,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
