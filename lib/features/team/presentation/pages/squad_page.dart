import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/team_snapshot.dart';
import '../bloc/team_bloc.dart';
import '../bloc/team_state.dart';

/// Player cards, season stats, and your profile. Profile detail (contact,
/// nationality, preferred positions, game reminders) is a later pass —
/// tapping it here opens the read-only [ProfilePage] for now.
class SquadPage extends StatelessWidget {
  const SquadPage({super.key, required this.user});

  final AppUser user;

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
            final roster = state.snapshot.roster;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  'SQUAD · 2026 SEASON',
                  style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push(AppRoutes.profile, extra: user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.teamGold,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'You',
                            style: AppTextStyles.heading(size: 11, color: AppColors.neutral800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your profile',
                                style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Contact details · positions · reminders',
                                style: AppTextStyles.body(
                                  size: 11.5,
                                  weight: FontWeight.w500,
                                  color: AppColors.text.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '›',
                          style: AppTextStyles.body(
                            size: 18,
                            weight: FontWeight.w700,
                            color: AppColors.text.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < roster.length; i++)
                        _RosterRow(
                          member: roster[i],
                          showTopBorder: i > 0,
                          onTap: () => context.push(AppRoutes.teamPlayer, extra: roster[i]),
                        ),
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

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.member,
    required this.showTopBorder,
    required this.onTap,
  });

  final SquadMember member;
  final bool showTopBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: showTopBorder
              ? Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.07)))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.neutral900,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${member.ovr}',
                style: AppTextStyles.heading(size: 13, color: AppColors.teamGold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name, style: AppTextStyles.body(size: 13, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${member.position} · ${member.seasonLine}',
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
              '›',
              style: AppTextStyles.body(
                size: 18,
                weight: FontWeight.w700,
                color: AppColors.text.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
