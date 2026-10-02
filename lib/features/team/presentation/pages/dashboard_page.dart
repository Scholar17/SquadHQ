import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/clock/clock_scope.dart';
import '../../../../core/notifications/web_push_prompt.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../match/domain/entities/match.dart' as match_entity;
import '../../../match/domain/entities/match_history.dart';
import '../../../match/presentation/bloc/match_bloc.dart';
import '../../../match/presentation/bloc/match_history_bloc.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../../match/presentation/pages/match_history_page.dart'
    show MatchHistoryArgs, ResultScore;
import '../../../match/presentation/pages/past_match_page.dart';
import '../../../match/presentation/bloc/match_state.dart';
import '../../../match/presentation/widgets/create_match_sheet.dart';
import '../../../match/presentation/widgets/upcoming_matches_section.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../team_membership/domain/entities/team.dart' as membership;
import '../../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_state.dart';
import '../../../team_membership/presentation/widgets/team_switcher_sheet.dart';
import '../../../wallet/presentation/wallet_formatting.dart';
import '../../domain/entities/team_snapshot.dart' show SquadRole, TeamInfo;
import '../bloc/team_bloc.dart';
import '../bloc/team_event.dart';
import '../pending_actions.dart';
import '../view_role.dart';
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

  void _onRoleToggle(BuildContext context, membership.TeamRole role) {
    if (role == membership.TeamRole.player) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Only team admins can switch to the Manager view')),
        );
      return;
    }
    context.read<TeamBloc>().add(const TeamRoleToggled());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<TeamMembershipBloc, TeamMembershipState>(
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
                onProfileTap: () => context.push(AppRoutes.profile, extra: user),
                onCreateOrJoin: () => context.push(AppRoutes.team),
              );
            }
            final teamState = context.watch<TeamBloc>().state;
            final viewRole = viewRoleFor(active.role, teamState);
            final canCreateMatch = viewRole == SquadRole.manager;
            final pending = PendingActions.of(context, user.id);
            return BlocBuilder<MatchBloc, MatchState>(
              builder: (context, matchState) => _DashboardContent(
                headerTeam: TeamInfo(
                  name: active.name,
                  meta: 'Invite code · ${active.inviteCode}',
                  initials: _initialsFor(active.name),
                  alertCount: context.watch<NotificationBloc>().state.unreadCount,
                ),
                role: viewRole,
                matches: _settledMatches(matchState),
                canCreateMatch: canCreateMatch,
                profileInitials: _profileInitials,
                onBellTap: () => context.push(
                  AppRoutes.notifications,
                  extra: NotificationsArgs(
                    userId: user.id,
                    adminViewIsManager:
                        viewRoleFor(membership.TeamRole.admin, teamState) == SquadRole.manager,
                  ),
                ),
                onMatchTap: (match) => context.push(
                  AppRoutes.upcomingMatch,
                  extra: UpcomingMatchArgs(
                    matchId: match.id,
                    teamName: active.name,
                    userId: user.id,
                    isManager: canCreateMatch,
                  ),
                ),
                afterTheMatch: _AfterTheMatch(
                  recaps: pending.recaps,
                  teamId: active.id,
                  teamName: active.name,
                  userId: user.id,
                  isManager: canCreateMatch,
                ),
                onTeamTap: () => showTeamSwitcherSheet(context),
                onRoleToggle: () => _onRoleToggle(context, active.role),
                onCreateMatch: () => showCreateMatchSheet(context, teamId: active.id),
                onSeeAllMatches: () => context.push(
                  AppRoutes.matches,
                  extra: MatchListArgs(
                    activeTeamId: active.id,
                    teamName: active.name,
                    userId: user.id,
                    canCreateMatch: canCreateMatch,
                  ),
                ),
                onProfileTap: () => context.push(AppRoutes.profile, extra: user),
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
    required this.onBellTap,
    required this.onMatchTap,
    required this.afterTheMatch,
    required this.onTeamTap,
    required this.onRoleToggle,
    required this.onCreateMatch,
    required this.onSeeAllMatches,
    required this.onProfileTap,
  });

  final TeamInfo headerTeam;
  final SquadRole role;
  final List<match_entity.Match> matches;
  final bool canCreateMatch;
  final String profileInitials;
  final VoidCallback onBellTap;
  final ValueChanged<match_entity.Match> onMatchTap;
  final Widget afterTheMatch;
  final VoidCallback onTeamTap;
  final VoidCallback onRoleToggle;
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
            onRoleToggle: onRoleToggle,
            onBellTap: onBellTap,
            onProfileTap: onProfileTap,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.list(
            children: [
              const WebPushPrompt(),
              UpcomingMatchesSection(
                matches: matches,
                canCreateMatch: canCreateMatch,
                onCreateMatch: onCreateMatch,
                onSeeAll: onSeeAllMatches,
                onMatchTap: onMatchTap,
              ),
              const SizedBox(height: 20),
              afterTheMatch,
            ],
          ),
        ),
      ],
    );
  }
}

/// Home's "After the match" section: a recap per match that finished in
/// the last week (kick-off + play time has passed) — result, Man of the
/// Match vote, and the viewer's unpaid fee. Shows up to [previewCount],
/// with "See all matches" (the match history) once there are more.
class _AfterTheMatch extends StatelessWidget {
  const _AfterTheMatch({
    required this.recaps,
    required this.teamId,
    required this.teamName,
    required this.userId,
    required this.isManager,
  });

  static const previewCount = 3;

  final List<MatchRecap> recaps;
  final String teamId;
  final String teamName;
  final String userId;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      'AFTER THE MATCH',
      style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
    );
    if (recaps.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 8),
            Text(
              'Once a match finishes, its result, the Man of the Match vote and '
              'your match fee show up here.',
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
    final history = context.watch<MatchHistoryBloc>().state.history ?? const MatchHistory();
    final preview = recaps.take(previewCount);
    // The count is what "See all" opens — the whole history, not just this
    // week's recaps (falls back to those until the history has loaded).
    final total = history.matches.length > recaps.length ? history.matches.length : recaps.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        const SizedBox(height: 10),
        for (final (index, recap) in preview.indexed) ...[
          if (index > 0) const SizedBox(height: 10),
          _RecapCard(
            recap: recap,
            history: history,
            onOpen: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => PastMatchPage(
                  matchId: recap.pastMatch.match.id,
                  teamName: teamName,
                  userId: userId,
                  isManager: isManager,
                ),
              ),
            ),
            // Paying lives in the Wallet tab only.
            onPay: () => context.go(AppRoutes.wallet),
            canAddScore: isManager,
          ),
        ],
        if (recaps.length > previewCount) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => context.push(
                AppRoutes.matchHistory,
                extra: MatchHistoryArgs(
                  teamId: teamId,
                  teamName: teamName,
                  userId: userId,
                  isManager: isManager,
                ),
              ),
              child: Text(
                'See all matches ($total)',
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.accent700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({
    required this.recap,
    required this.history,
    required this.onOpen,
    required this.onPay,
    required this.canAddScore,
  });

  final MatchRecap recap;
  final MatchHistory history;
  final VoidCallback onOpen;
  final VoidCallback onPay;
  final bool canAddScore;

  @override
  Widget build(BuildContext context) {
    final pastMatch = recap.pastMatch;
    final match = pastMatch.match;
    final owed = recap.owed;
    final tally = pastMatch.motmTally;
    final winnerIds = pastMatch.motmWinnerIds;
    final winners = [
      for (final member in history.members)
        if (winnerIds.contains(member.profileId)) member.name,
    ];
    final now = ClockScope.now(context);
    final decided = history.motmDecided(pastMatch, now);
    final voters = history.motmVoters(pastMatch);
    final votesCast =
        voters.where((voter) => pastMatch.motmVotes.containsKey(voter.profileId)).length;
    // Secret ballot until decided (everyone voted, or midnight after).
    final motmText = !decided
        ? 'Man of the Match voting open · $votesCast of ${voters.length} voted'
        : winners.isEmpty
            ? 'No Man of the Match — nobody voted'
            : 'Man of the Match: ${winners.join(' & ')} '
                '(${tally[winnerIds.first]} ${tally[winnerIds.first] == 1 ? 'vote' : 'votes'}'
                '${winners.length > 1 ? ' each' : ''})';
    final muted = AppTextStyles.body(
      size: 12.5,
      weight: FontWeight.w600,
      color: AppColors.text.withValues(alpha: 0.6),
    );
    return Material(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('vs ${match.opponent}', style: AppTextStyles.heading(size: 16)),
                        const SizedBox(height: 2),
                        Text(formatMatchDate(match.kickoffAt), style: muted),
                      ],
                    ),
                  ),
                  if (match.result != null)
                    ResultScore(match: match)
                  else if (canAddScore)
                    _PillButton(label: 'Add score', onPressed: onOpen)
                  else
                    Text('No score yet', style: muted),
                ],
              ),
              const SizedBox(height: 12),
              if (recap.needsMotmVote)
                _ActionRow(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppColors.teamGold,
                  text: 'Vote for Man of the Match',
                  highlight: true,
                  action: _PillButton(label: 'Vote now', primary: true, onPressed: onOpen),
                )
              else
                _ActionRow(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppColors.teamGold,
                  text: motmText,
                ),
              if (owed != null) ...[
                const SizedBox(height: 8),
                _ActionRow(
                  icon: Icons.payments_rounded,
                  iconColor: AppColors.accent700,
                  text: 'You owe ${formatBaht(owed.$2.roundedShare)} to ${owed.$2.bill.payerName}',
                  highlight: true,
                  action: _PillButton(label: 'Go to Wallet', primary: true, onPressed: onPay),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.highlight = false,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final bool highlight;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, action == null ? 12 : 8, 8),
      decoration: BoxDecoration(
        color: highlight ? AppColors.accent100 : AppColors.neutral200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body(
                size: 12.5,
                weight: FontWeight.w700,
                color: highlight ? AppColors.accent900 : AppColors.text,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onPressed, this.primary = false});

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: primary ? AppColors.neutral100 : AppColors.text,
        backgroundColor: primary ? AppColors.accent : AppColors.neutral200,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        label,
        style: AppTextStyles.heading(
          size: 12.5,
          color: primary ? AppColors.neutral100 : AppColors.text,
        ),
      ),
    );
  }
}
