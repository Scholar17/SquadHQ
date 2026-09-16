import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../domain/entities/team_snapshot.dart';
import '../bloc/team_bloc.dart';
import '../bloc/team_event.dart';
import '../bloc/team_state.dart';
import '../widgets/last_time_out_card.dart';
import '../widgets/matchday_hero_card.dart';
import '../widgets/needs_you_list.dart';
import '../widgets/team_header.dart';

/// The "Home" tab — the app's daily HQ. Matches the prototype's hero-card
/// layout variant: matchday hero, "Needs you" actions, last result recap.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.user});

  final AppUser user;

  String get _profileInitials {
    final source = user.username ?? user.name;
    return source.isNotEmpty ? source[0].toUpperCase() : '?';
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<TeamBloc, TeamState>(
          builder: (context, state) {
            return switch (state) {
              TeamLoading() =>
                const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              TeamError(:final message) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(color: AppColors.accent700),
                    ),
                  ),
                ),
              TeamLoaded(:final snapshot, :final isManager, :final myRsvp) =>
                _DashboardContent(
                  snapshot: snapshot,
                  isManager: isManager,
                  myRsvp: myRsvp,
                  profileInitials: _profileInitials,
                  onRoleToggle: () =>
                      context.read<TeamBloc>().add(const TeamRoleToggled()),
                  onRsvp: (status) =>
                      context.read<TeamBloc>().add(TeamMyRsvpChanged(status)),
                  onAction: (label) => _showComingSoon(context, label),
                  onProfileTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfilePage(user: user),
                    ),
                  ),
                ),
            };
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.isManager,
    required this.myRsvp,
    required this.profileInitials,
    required this.onRoleToggle,
    required this.onRsvp,
    required this.onAction,
    required this.onProfileTap,
  });

  final TeamSnapshot snapshot;
  final bool isManager;
  final RsvpStatus myRsvp;
  final String profileInitials;
  final VoidCallback onRoleToggle;
  final ValueChanged<RsvpStatus> onRsvp;
  final ValueChanged<String> onAction;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TeamHeader(
            team: snapshot.team,
            role: isManager ? SquadRole.manager : SquadRole.player,
            profileInitials: profileInitials,
            onTeamTap: () => onAction('Switching teams'),
            onRoleToggle: onRoleToggle,
            onBellTap: () => onAction('Notifications'),
            onProfileTap: onProfileTap,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'THIS SUNDAY',
                      style: AppTextStyles.label(
                        color: AppColors.text.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  if (isManager)
                    TextButton(
                      onPressed: () => onAction('New match'),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.bg,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        '+ New match',
                        style: AppTextStyles.heading(size: 12, color: AppColors.bg),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              MatchdayHeroCard(
                match: snapshot.match,
                isManager: isManager,
                myRsvp: myRsvp,
                onOpenMatchday: () => onAction('Matchday hub'),
                onRemind: () => onAction('Reminder'),
                onRsvpIn: () => onRsvp(RsvpStatus.yes),
                onRsvpOut: () => onRsvp(RsvpStatus.no),
              ),
              const SizedBox(height: 20),
              NeedsYouList(
                items: snapshot.needsYou,
                onTap: (item) => onAction(item.title),
              ),
              const SizedBox(height: 20),
              LastTimeOutCard(result: snapshot.lastResult),
            ],
          ),
        ),
      ],
    );
  }
}
