import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../../match/domain/entities/match.dart' as match_entity;
import '../../../match/presentation/bloc/match_bloc.dart';
import '../../../match/presentation/bloc/match_event.dart';
import '../../../match/presentation/bloc/match_state.dart';
import '../../../match/presentation/pages/match_list_page.dart';
import '../../../match/presentation/widgets/create_match_sheet.dart';
import '../../../match/presentation/widgets/upcoming_matches_section.dart';
import '../../../team_membership/domain/entities/team.dart' as membership;
import '../../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_state.dart';
import '../../../team_membership/presentation/pages/team_membership_page.dart';
import '../../../team_membership/presentation/pages/team_roster_page.dart';
import '../../../team_membership/presentation/widgets/team_switcher_sheet.dart';
import '../../domain/entities/team_snapshot.dart' show SquadRole, TeamInfo;
import '../widgets/team_header.dart';

/// The "Home" tab — the app's daily HQ. Team header and upcoming matches
/// are real (team_membership + match features, both Supabase-backed); the
/// wallet ledger, MOTM voting and match-result recaps the prototype used
/// to fake aren't backed by any table yet, so this shows an honest
/// "coming soon" card there instead of the old mock [TeamBloc] data.
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

  /// Unwraps Submitting/Failure down to the settled Loaded state — those
  /// two never nest, so one pass is enough (same invariant as elsewhere).
  static TeamMembershipState _settle(TeamMembershipState state) => switch (state) {
        TeamMembershipSubmitting(:final previous) => previous,
        TeamMembershipFailure(:final previous) => previous,
        _ => state,
      };

  static membership.Team? _activeTeam(TeamMembershipState state) {
    final settled = _settle(state);
    if (settled is! TeamMembershipLoaded) return null;
    for (final team in settled.teams) {
      if (team.isActive) return team;
    }
    return null;
  }

  static List<match_entity.Match> _settledMatches(MatchState state) => switch (state) {
        MatchLoaded(:final matches) => matches,
        MatchSubmitting(:final previous) => _settledMatches(previous),
        MatchFailure(:final previous) => _settledMatches(previous),
        _ => const [],
      };

  static String _initialsFor(String name) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return initials.isEmpty ? '?' : initials;
  }

  /// [TeamHeader] only distinguishes manager/player; super admin and admin
  /// both read as "Manager" there, matching how [canCreateMatch] elsewhere
  /// already treats anything above [membership.TeamRole.player] as one tier.
  static SquadRole _squadRoleFor(membership.TeamRole role) =>
      role == membership.TeamRole.player ? SquadRole.player : SquadRole.manager;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<TeamMembershipBloc, TeamMembershipState>(
          listenWhen: (previous, current) =>
              _activeTeam(previous)?.id != _activeTeam(current)?.id,
          listener: (context, state) => context
              .read<MatchBloc>()
              .add(MatchTeamSelected(_activeTeam(state)?.id)),
          builder: (context, membershipState) {
            final settled = _settle(membershipState);
            if (settled is! TeamMembershipLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }
            final active = _activeTeam(membershipState);
            if (active == null) {
              return _EmptyHome(
                profileInitials: _profileInitials,
                onProfileTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfilePage(user: user),
                  ),
                ),
                onCreateOrJoin: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TeamMembershipPage(),
                  ),
                ),
              );
            }
            final canCreateMatch = active.role != membership.TeamRole.player;
            return BlocBuilder<MatchBloc, MatchState>(
              builder: (context, matchState) => _DashboardContent(
                headerTeam: TeamInfo(
                  name: active.name,
                  meta: 'Invite code · ${active.inviteCode}',
                  initials: _initialsFor(active.name),
                  alertCount: 0,
                ),
                role: _squadRoleFor(active.role),
                matches: _settledMatches(matchState),
                canCreateMatch: canCreateMatch,
                profileInitials: _profileInitials,
                onAction: (label) => _showComingSoon(context, label),
                onTeamTap: () => showTeamSwitcherSheet(context),
                onManageRoles: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TeamRosterPage(team: active),
                  ),
                ),
                onCreateMatch: () => showCreateMatchSheet(context, teamId: active.id),
                onSeeAllMatches: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MatchListPage(
                      activeTeamId: active.id,
                      canCreateMatch: canCreateMatch,
                    ),
                  ),
                ),
                onProfileTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfilePage(user: user),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Home's empty state — a signed-in profile with no real team yet. Reachable
/// straight from the app shell (see app.dart's _TeamGate) rather than a
/// separate full-screen gate, so the bottom nav stays visible.
class _EmptyHome extends StatelessWidget {
  const _EmptyHome({
    required this.profileInitials,
    required this.onProfileTap,
    required this.onCreateOrJoin,
  });

  final String profileInitials;
  final VoidCallback onProfileTap;
  final VoidCallback onCreateOrJoin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.neutral300,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    profileInitials,
                    style: AppTextStyles.body(size: 12, weight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.teamGold,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.groups_rounded,
                      color: AppColors.neutral800,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "You're not on a team yet",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading(size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a squad of your own, or join one with an invite '
                    'code, to see fixtures and squad stats here.',
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
                      onPressed: onCreateOrJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.bg,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(
                        'Create or join a team',
                        style: AppTextStyles.heading(size: 14, color: AppColors.bg),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.headerTeam,
    required this.role,
    required this.matches,
    required this.canCreateMatch,
    required this.profileInitials,
    required this.onAction,
    required this.onTeamTap,
    required this.onManageRoles,
    required this.onCreateMatch,
    required this.onSeeAllMatches,
    required this.onProfileTap,
  });

  final TeamInfo headerTeam;
  final SquadRole role;
  final List<match_entity.Match> matches;
  final bool canCreateMatch;
  final String profileInitials;
  final ValueChanged<String> onAction;
  final VoidCallback onTeamTap;
  final VoidCallback onManageRoles;
  final VoidCallback onCreateMatch;
  final VoidCallback onSeeAllMatches;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TeamHeader(
            team: headerTeam,
            role: role,
            profileInitials: profileInitials,
            onTeamTap: onTeamTap,
            onRoleToggle: onManageRoles,
            onBellTap: () => onAction('Notifications'),
            onProfileTap: onProfileTap,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.list(
            children: [
              UpcomingMatchesSection(
                matches: matches,
                canCreateMatch: canCreateMatch,
                onCreateMatch: onCreateMatch,
                onSeeAll: onSeeAllMatches,
              ),
              const SizedBox(height: 20),
              const _ComingSoonCard(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Same card styling as the prototype's "Last time out" recap, but honest
/// about there being no wallet/voting/result data behind it yet.
class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMING SOON',
            style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 8),
          Text(
            'Match fees, MOTM voting and result recaps are on the way.',
            style: AppTextStyles.body(
              size: 12.5,
              weight: FontWeight.w500,
              color: AppColors.text.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
