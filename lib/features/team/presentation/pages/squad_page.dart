import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/empty_state.dart';
import '../../../../core/theme/widgets/skeletons.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../player_rating/domain/entities/player_rating.dart';
import '../../../player_rating/presentation/bloc/team_ratings_bloc.dart';
import '../../../player_rating/presentation/pages/player_card_page.dart';
import '../../../player_rating/presentation/pages/rating_quiz_page.dart';
import '../../../player_rating/presentation/rating_changes.dart';
import '../../../squad/presentation/active_group.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart' show SquadAvatar;
import '../../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_state.dart';

/// The team's squad with real ratings (supabase/sql/045_player_ratings.sql):
/// the team's average OVR, then everyone best-first. Your own row's
/// "Fill rating" button is the only way to rate yourself; "Level up"
/// shows once 10 matches are in.
class SquadPage extends StatelessWidget {
  const SquadPage({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final membership = context.watch<TeamMembershipBloc>().state;
    final teamId = activeGroupOf(membership)?.id;
    // No team yet (a brand-new account): nothing to load ratings for, so
    // say so rather than leaving the skeleton up forever.
    if (teamId == null && _settled(membership) is TeamMembershipLoaded) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: EmptyState(
            icon: Icons.groups_rounded,
            title: "You're not on a team yet",
            body: 'Create or join a team to see its squad and player ratings here.',
            actionLabel: 'Create or join a team',
            onAction: () => context.push(AppRoutes.team),
          ),
        ),
      );
    }
    return BlocProvider(
      // A fresh bloc per team, so one team's squad never shows on another.
      key: ValueKey(teamId),
      create: (_) {
        final bloc = sl<TeamRatingsBloc>();
        if (teamId != null) bloc.add(TeamRatingsStarted(teamId));
        return bloc;
      },
      child: _SquadView(user: user),
    );
  }

  /// Unwraps Submitting/Failure down to the settled state underneath.
  static TeamMembershipState _settled(TeamMembershipState state) => switch (state) {
    TeamMembershipSubmitting(:final previous) || TeamMembershipFailure(:final previous) => previous,
    _ => state,
  };
}

class _SquadView extends StatefulWidget {
  const _SquadView({required this.user});

  final AppUser user;

  @override
  State<_SquadView> createState() => _SquadViewState();
}

class _SquadViewState extends State<_SquadView> {
  @override
  void initState() {
    super.initState();
    ratingChanges.addListener(_refresh);
  }

  @override
  void dispose() {
    ratingChanges.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => context.read<TeamRatingsBloc>().add(const TeamRatingsRefreshed());

  Future<void> _fillRating() async {
    final rated = await showRatingQuiz(context, playerName: widget.user.name);
    if (rated != null && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.user.id;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: BlocConsumer<TeamRatingsBloc, TeamRatingsState>(
          listenWhen: (previous, current) =>
              current.improvedTo != null ||
              (current.error != null && current.error != previous.error),
          listener: (context, state) {
            final message = state.improvedTo != null
                ? 'Levelled up — you\'re now ${state.improvedTo} OVR'
                : state.error;
            if (message == null) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          },
          builder: (context, state) {
            final players = state.players;
            if (players == null) {
              return const SkeletonList(item: ExpenseRowSkeleton(), count: 6, spacing: 8);
            }
            final mine = players.where((player) => player.profileId == me).firstOrNull;
            return RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () async {
                _refresh();
                // Same data back emits nothing — don't spin forever.
                await context
                    .read<TeamRatingsBloc>()
                    .stream
                    .firstWhere((next) => next.players != players)
                    .timeout(const Duration(seconds: 8), onTimeout: () => state);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Text(
                    'SQUAD · ${DateTime.now().year} SEASON',
                    style: AppTextStyles.label(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  _ProfileRow(onTap: () => context.push(AppRoutes.profile, extra: widget.user)),
                  const SizedBox(height: 14),
                  _TeamRatingCard(players: players),
                  const SizedBox(height: 14),
                  if (mine != null && mine.canImprove) ...[
                    _Callout(
                      title: '${RatedPlayer.boostEvery} matches played',
                      body: 'Level up your card from the goals, assists and saves you logged.',
                      action: state.improving ? 'Levelling up…' : 'Level up',
                      onAction: state.improving
                          ? null
                          : () => context.read<TeamRatingsBloc>().add(
                              const TeamRatingImproveRequested(),
                            ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                      borderRadius: AppRadius.lg,
                    ),
                    child: Column(
                      children: [
                        for (final (index, player) in players.indexed)
                          _RosterRow(
                            player: player,
                            isMe: player.profileId == me,
                            showTopBorder: index > 0,
                            onFillRating: _fillRating,
                            onTap: () =>
                                showPlayerCard(context, profileId: player.profileId, me: me),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The team's average OVR (of those rated) and each stat's average.
class _TeamRatingCard extends StatelessWidget {
  const _TeamRatingCard({required this.players});

  final List<RatedPlayer> players;

  @override
  Widget build(BuildContext context) {
    final average = players.averageOvr;
    final rated = [for (final player in players) ?player.rating];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.darkHero(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEAM RATING',
                      style: AppTextStyles.label(color: AppColors.teamGold)
                          .copyWith(letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${players.ratedCount} of ${players.length} players rated',
                      style: AppTextStyles.body(size: 12.5, color: AppColors.onDarkMuted),
                    ),
                  ],
                ),
              ),
              Text(
                average == null ? '—' : '$average',
                style: AppTextStyles.heading(size: 44, color: AppColors.teamGold),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'AVG',
                  style: AppTextStyles.label(size: 10, color: AppColors.onDarkMuted),
                ),
              ),
            ],
          ),
          if (rated.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (final key in StatKey.values)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${(rated.map((r) => r.stat(key)).reduce((a, b) => a + b) / rated.length).round()}',
                          style: AppTextStyles.title(size: 15, color: AppColors.onDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          key.short,
                          style: AppTextStyles.label(size: 9.5, color: AppColors.onDarkMuted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.accent100,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.title(size: 14.5, color: AppColors.accent900)),
                const SizedBox(height: 2),
                Text(body, style: AppTextStyles.body(size: 12, color: AppColors.accent800)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _PillButton(label: action, onPressed: onAction),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onDark,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: AppTextStyles.title(size: 12.5, color: AppColors.onDark)),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.lg,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.lg),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: AppColors.teamGold, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('You', style: AppTextStyles.title(size: 11, color: AppColors.neutral800)),
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
                    'Contact details · bank details · appearance',
                    style: AppTextStyles.body(size: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.player,
    required this.isMe,
    required this.showTopBorder,
    required this.onTap,
    required this.onFillRating,
  });

  final RatedPlayer player;
  final bool isMe;
  final bool showTopBorder;
  final VoidCallback onTap;
  final VoidCallback onFillRating;

  @override
  Widget build(BuildContext context) {
    final rating = player.rating;
    final initial = player.name.trim().isEmpty ? '?' : player.name.trim()[0].toUpperCase();
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.neutral900, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                rating == null ? '—' : '${rating.ovr}',
                style: AppTextStyles.title(size: 14, color: AppColors.teamGold),
              ),
            ),
            const SizedBox(width: 10),
            SquadAvatar(initial: initial, photoUrl: player.avatarUrl, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${player.name} (you)' : player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rating == null
                        ? 'No rating yet'
                        : '${rating.positions.join(' · ')} · ${player.apps} '
                              '${player.apps == 1 ? 'app' : 'apps'}',
                    style: AppTextStyles.body(size: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (isMe && rating == null)
              _PillButton(label: 'Fill rating', onPressed: onFillRating)
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
