import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_member.dart';
import '../bloc/team_membership_bloc.dart';
import '../bloc/team_membership_event.dart';
import '../bloc/team_roster_bloc.dart';
import '../bloc/team_roster_event.dart';
import '../bloc/team_roster_state.dart';

/// Reached from a team card's "Manage team" action. [team] is the caller's
/// own membership row, so [Team.role] tells this page whether to show
/// super-admin-only controls (promote/demote, delete team).
class TeamRosterPage extends StatelessWidget {
  const TeamRosterPage({super.key, required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TeamRosterBloc>(param1: team.id)..add(const TeamRosterStarted()),
      child: _TeamRosterView(team: team),
    );
  }
}

class _TeamRosterView extends StatelessWidget {
  const _TeamRosterView({required this.team});

  final Team team;

  bool get _isSuperAdmin => team.role == TeamRole.superAdmin;

  TeamRosterState _settle(TeamRosterState state) => switch (state) {
    TeamRosterSubmitting(:final previous) => previous,
    TeamRosterFailure(:final previous) => previous,
    _ => state,
  };

  Future<void> _confirmDeleteTeam(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.neutral100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${team.name}?', style: AppTextStyles.heading(size: 20)),
        content: Text(
          'This removes the team and every member from it. This cannot be undone.',
          style: AppTextStyles.body(size: 13.5, color: AppColors.text.withValues(alpha: 0.7)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: AppTextStyles.body(size: 14, weight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: AppTextStyles.body(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.accent700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<TeamRosterBloc>().add(const TeamRosterDeleteTeamRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TeamRosterBloc, TeamRosterState>(
      listener: (context, state) {
        if (state case TeamRosterFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
        if (state is TeamRosterTeamDeleted) {
          context.read<TeamMembershipBloc>().add(const TeamMembershipStarted());
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.text,
          title: Text(team.name, style: AppTextStyles.heading(size: 16)),
        ),
        body: SafeArea(
          child: BlocBuilder<TeamRosterBloc, TeamRosterState>(
            builder: (context, state) {
              final isSubmitting = state is TeamRosterSubmitting;
              final settled = _settle(state);
              if (settled is! TeamRosterLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    'ROSTER',
                    style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                  ),
                  const SizedBox(height: 10),
                  for (final member in settled.members) ...[
                    _MemberRow(
                      member: member,
                      canManage: _isSuperAdmin && member.role != TeamRole.superAdmin,
                      isSubmitting: isSubmitting,
                      onPromote: () => context.read<TeamRosterBloc>().add(
                        TeamRosterPromoteRequested(member.profileId),
                      ),
                      onDemote: () => context.read<TeamRosterBloc>().add(
                        TeamRosterDemoteRequested(member.profileId),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_isSuperAdmin) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => _confirmDeleteTeam(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.accent700.withValues(alpha: 0.4)),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Delete team',
                          style: AppTextStyles.heading(size: 14, color: AppColors.accent700),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canManage,
    required this.isSubmitting,
    required this.onPromote,
    required this.onDemote,
  });

  final TeamMember member;
  final bool canManage;
  final bool isSubmitting;
  final VoidCallback onPromote;
  final VoidCallback onDemote;

  static String _roleLabel(TeamRole role) => switch (role) {
    TeamRole.superAdmin => 'SUPER ADMIN',
    TeamRole.admin => 'ADMIN',
    TeamRole.player => 'PLAYER',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.teamGold,
            // Foreground, so an expired photo link falls back to the initials.
            foregroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
            onForegroundImageError: member.avatarUrl != null ? (_, _) {} : null,
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: AppTextStyles.heading(size: 14, color: AppColors.neutral800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: AppTextStyles.body(size: 14, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  _roleLabel(member.role),
                  style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
          if (canManage)
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : (member.role == TeamRole.admin ? onDemote : onPromote),
              child: Text(
                member.role == TeamRole.admin ? 'Remove admin' : 'Make admin',
                style: AppTextStyles.body(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: AppColors.accent700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
