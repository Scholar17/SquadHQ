import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team.dart';
import '../bloc/team_membership_bloc.dart';
import '../bloc/team_membership_event.dart';
import '../bloc/team_membership_state.dart';

/// Opened from the Home header's team name — lets the profile jump between
/// its teams (up to 3), or head to [TeamMembershipPage] to create/join one.
Future<void> showTeamSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _TeamSwitcherSheet(),
  );
}

class _TeamSwitcherSheet extends StatelessWidget {
  const _TeamSwitcherSheet();

  /// Same one-pass unwrap as [TeamMembershipPage] — Submitting/Failure
  /// never nest, so this always bottoms out at [TeamMembershipLoaded].
  static TeamMembershipState _settle(TeamMembershipState state) => switch (state) {
        TeamMembershipSubmitting(:final previous) => previous,
        TeamMembershipFailure(:final previous) => previous,
        _ => state,
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your groups', style: AppTextStyles.heading(size: 18)),
            const SizedBox(height: 14),
            BlocBuilder<TeamMembershipBloc, TeamMembershipState>(
              builder: (context, state) {
                final settled = _settle(state);
                final teams =
                    settled is TeamMembershipLoaded ? settled.teams : const <Team>[];
                if (teams.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      "You're not on a team yet.",
                      style: AppTextStyles.body(
                        size: 13.5,
                        color: AppColors.text.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final team in teams)
                      _TeamRow(
                        team: team,
                        onTap: team.isActive
                            ? null
                            : () {
                                context
                                    .read<TeamMembershipBloc>()
                                    .add(TeamSwitchRequested(team.id));
                                Navigator.of(context).pop();
                              },
                      ),
                  ],
                );
              },
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.team);
              },
              child: Text(
                '+ Create or join a group',
                style: AppTextStyles.heading(size: 13, color: AppColors.accent700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.team, required this.onTap});

  final Team team;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: team.isActive
                  ? AppColors.accent
                  : AppColors.text.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                team.isSquad ? Icons.receipt_long_rounded : Icons.sports_soccer_rounded,
                size: 20,
                color: AppColors.text.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: AppTextStyles.body(size: 14, weight: FontWeight.w700, height: 1.3),
                    ),
                    Text(
                      team.isSquad ? 'Squad' : 'Football team',
                      style: AppTextStyles.body(
                        size: 11.5,
                        color: AppColors.text.withValues(alpha: 0.55),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (team.isActive)
                Text('ACTIVE', style: AppTextStyles.label(color: AppColors.accent700))
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.text.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
