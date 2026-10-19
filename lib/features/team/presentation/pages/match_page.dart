import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/skeletons.dart';
import '../../../../core/theme/widgets/empty_state.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../comments/domain/entities/match_topic.dart';
import '../../../comments/presentation/widgets/match_comments.dart';
import '../../../match/domain/entities/match.dart' as match_entity;
import '../../../match/domain/entities/matchday_player.dart';
import '../../../match/presentation/bloc/match_bloc.dart';
import '../../../match/presentation/bloc/match_event.dart';
import '../../../match/presentation/bloc/match_state.dart';
import '../../../match/presentation/bloc/matchday_bloc.dart';
import '../../../match/presentation/bloc/matchday_event.dart';
import '../../../match/presentation/bloc/matchday_state.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../../match/presentation/pages/match_history_page.dart';
import '../../../match/presentation/widgets/cancel_match_dialog.dart';
import '../../../match/presentation/widgets/match_history_widgets.dart';
import '../../../match/presentation/widgets/create_match_sheet.dart';
import '../../../share/domain/entities/share_link.dart';
import '../../../share/presentation/widgets/share_link_button.dart';
import '../../../team_membership/domain/entities/team.dart' as membership;
import '../../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_state.dart';
import '../../../venue/domain/entities/venue.dart';
import '../../../venue/presentation/widgets/venue_details_sheet.dart';
import '../../../venue/presentation/widgets/venue_builder.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../wallet/presentation/widgets/bill_card.dart';
import '../../../weather/presentation/widgets/kickoff_conditions.dart';
import '../../domain/entities/team_snapshot.dart' show SquadRole;
import '../view_role.dart';
import '../widgets/profile_corner.dart';

/// The matchday hub for the active team's next match — RSVP, the match
/// bill, squad list, and (for admins in the Manager view) edit/cancel.
/// Backed by supabase/sql/006–008; the bill comes from the app-root
/// [WalletBloc], so it's the same bill the Wallet tab shows.
class MatchPage extends StatelessWidget {
  const MatchPage({super.key, required this.user});

  final AppUser user;

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

  static List<match_entity.Match>? _settledMatches(MatchState state) => switch (state) {
    MatchLoaded(:final matches) => matches,
    MatchSubmitting(:final previous) => _settledMatches(previous),
    MatchFailure(:final previous) => _settledMatches(previous),
    MatchLoading() => null,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: BlocListener<MatchBloc, MatchState>(
          listenWhen: (previous, current) => current is MatchFailure,
          listener: (context, state) {
            if (state case MatchFailure(:final message)) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            }
          },
          child: BlocBuilder<TeamMembershipBloc, TeamMembershipState>(
            builder: (context, membershipState) {
              final active = _activeTeam(membershipState);
              if (active == null) {
                return ProfileCorner(
                  user: user,
                  child: _EmptyMatchday(
                    title: "You're not on a team yet",
                    body: 'Create or join a team to see its matchday here.',
                    actionLabel: 'Create or join a team',
                    onAction: () => context.push(AppRoutes.team),
                  ),
                );
              }
              final isManager =
                  viewRoleFor(active.role) == SquadRole.manager;
              final content = BlocBuilder<MatchBloc, MatchState>(
                builder: (context, matchState) {
                  final matches = _settledMatches(matchState);
                  if (matches == null) {
                    return const SkeletonList(item: MatchCardSkeleton(), count: 1);
                  }
                  if (matches.isEmpty) {
                    return _EmptyMatchday(
                      title: 'No upcoming match',
                      body: isManager
                          ? 'Schedule the next one and your squad can RSVP here.'
                          : "Your team's admin hasn't scheduled one yet.",
                      actionLabel: isManager ? '+ New match' : null,
                      onAction: () => showCreateMatchSheet(context, teamId: active.id),
                    );
                  }
                  // Always the closest match; the rest are one tap away.
                  final match = matches.first;
                  // Keyed by match id so switching teams, or cancelling
                  // this match, starts a fresh MatchdayBloc for the next one.
                  return BlocProvider(
                    key: ValueKey(match.id),
                    create: (_) => sl<MatchdayBloc>(param1: match)..add(const MatchdayStarted()),
                    child: _MatchdayView(
                      match: match,
                      teamName: active.name,
                      userId: user.id,
                      isManager: isManager,
                      moreUpcoming: matches.length - 1,
                      onSeeMore: () => context.push(
                        AppRoutes.matches,
                        extra: MatchListArgs(
                          activeTeamId: active.id,
                          teamName: active.name,
                          userId: user.id,
                          canCreateMatch: isManager,
                        ),
                      ),
                    ),
                  );
                },
              );
              return Column(
                children: [
                  _MatchTabHeader(
                    onHistory: () => context.push(
                      AppRoutes.matchHistory,
                      extra: MatchHistoryArgs(
                        teamId: active.id,
                        teamName: active.name,
                        userId: user.id,
                        isManager: isManager,
                      ),
                    ),
                  ),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "N more upcoming matches · See more", under the closest match.
class _SeeMoreBar extends StatelessWidget {
  const _SeeMoreBar({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neutral200,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.event_rounded, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count more upcoming ${count == 1 ? 'match' : 'matches'}',
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w600),
                ),
              ),
              Text('See more', style: AppTextStyles.title(size: 13, color: AppColors.accent700)),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.accent700),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single upcoming match's full matchday view — RSVP poll, bill, squad,
/// and admin edit/cancel — opened from the upcoming matches list. Reads
/// the match live from [MatchBloc], and closes itself if it's cancelled.
class UpcomingMatchPage extends StatelessWidget {
  const UpcomingMatchPage({super.key, required this.args});

  final UpcomingMatchArgs args;

  static match_entity.Match? _find(MatchState state, String matchId) {
    final matches = switch (state) {
      MatchLoaded(:final matches) => matches,
      MatchSubmitting(previous: MatchLoaded(:final matches)) => matches,
      MatchFailure(previous: MatchLoaded(:final matches)) => matches,
      _ => const <match_entity.Match>[],
    };
    for (final match in matches) {
      if (match.id == matchId) return match;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Match', style: AppTextStyles.title(size: 16)),
      ),
      body: BlocConsumer<MatchBloc, MatchState>(
        listenWhen: (previous, current) =>
            current is MatchLoaded && _find(current, args.matchId) == null,
        listener: (context, state) => Navigator.of(context).maybePop(),
        builder: (context, state) {
          final match = _find(state, args.matchId);
          if (match == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          return BlocProvider(
            key: ValueKey(match.id),
            create: (_) => sl<MatchdayBloc>(param1: match)..add(const MatchdayStarted()),
            child: _MatchdayView(
              match: match,
              teamName: args.teamName,
              userId: args.userId,
              isManager: args.isManager,
            ),
          );
        },
      ),
    );
  }
}

/// "Match" with a history button — past matches, scores and Man of the
/// Match live on their own page.
class _MatchTabHeader extends StatelessWidget {
  const _MatchTabHeader({required this.onHistory});

  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Same 20 from the top as Wallet's and Members' titles.
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text('Match', style: AppTextStyles.heading(size: 22))),
          IconButton(
            onPressed: onHistory,
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Match history',
            color: AppColors.text,
          ),
        ],
      ),
    );
  }
}

/// One match's RSVP poll, bill and squad — the Match tab's closest match,
/// or any upcoming match on [UpcomingMatchPage].
class _MatchdayView extends StatelessWidget {
  const _MatchdayView({
    required this.match,
    required this.teamName,
    required this.userId,
    required this.isManager,
    this.moreUpcoming = 0,
    this.onSeeMore,
  });

  final match_entity.Match match;
  final String teamName;
  final String userId;
  final bool isManager;

  /// How many other upcoming matches there are — shows a "See more" bar
  /// when there are any.
  final int moreUpcoming;
  final VoidCallback? onSeeMore;

  static MatchdayState _settle(MatchdayState state) => switch (state) {
    MatchdaySubmitting(:final previous) => previous,
    MatchdayFailure(:final previous) => previous,
    _ => state,
  };

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await confirmCancelMatch(
      context,
      opponent: match.opponent,
      walletMatch: context.read<WalletBloc>().state.wallet?.forMatch(match.id),
    );
    if (confirmed && context.mounted) {
      context.read<MatchBloc>().add(MatchDeleteRequested(match.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MatchdayBloc, MatchdayState>(
      listenWhen: (previous, current) =>
          current is MatchdayFailure ||
          (previous is MatchdaySubmitting && current is MatchdayLoaded),
      listener: (context, state) {
        if (state case MatchdayFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        // An RSVP changes who a "players who said In" bill splits between.
        context.read<WalletBloc>().add(const WalletRefreshRequested());
      },
      builder: (context, state) {
        final settled = _settle(state);
        final players = settled is MatchdayLoaded ? settled.players : const <MatchdayPlayer>[];
        MatchdayPlayer? me;
        for (final player in players) {
          if (player.profileId == userId) me = player;
        }
        // A player on the squad who hasn't voted gets the poll at the very
        // top, above the match header; after voting it moves back below.
        // Anyone on the squad can vote, in either view (admins play too),
        // and an unanswered vote is urgent for all of them — the poll glows
        // and says "YOUR VOTE NEEDED".
        final canVote = me != null;
        final needsAnswer = canVote && settled is MatchdayLoaded && me.answer == null;
        final isSubmitting = state is MatchdaySubmitting;
        void onRsvp(RsvpAnswer answer) =>
            context.read<MatchdayBloc>().add(MatchdayRsvpSubmitted(answer));
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _HubHeader(
              teamName: teamName,
              match: match,
              isManager: isManager,
              onEdit: () => showEditMatchSheet(context, match: match),
            ),
            if (moreUpcoming > 0 && onSeeMore != null) ...[
              const SizedBox(height: 10),
              _SeeMoreBar(count: moreUpcoming, onTap: onSeeMore!),
            ],
            const SizedBox(height: 16),
            if (settled is! MatchdayLoaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              )
            else ...[
              _RsvpPoll(
                match: match,
                roster: settled,
                userId: userId,
                myAnswer: me?.answer,
                canVote: canVote,
                urgent: needsAnswer,
                isSubmitting: isSubmitting,
                onRsvp: onRsvp,
              ),
              if (isManager && settled.countOf(null) > 0 && match.kickoffAt.isAfter(DateTime.now()))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _RemindPlayersButton(match: match, silent: settled.countOf(null)),
                ),
              _MatchBill(matchId: match.id, userId: userId, isManager: isManager),
              const SizedBox(height: 16),
              MatchCommentsButton(
                thread: (matchId: match.id, topic: MatchTopic.match),
                teamId: match.teamId,
                userId: userId,
                canModerate: isManager,
                subtitle: 'vs ${match.opponent} · ${formatMatchDate(match.kickoffAt)}',
              ),
              const SizedBox(height: 10),
              ShareLinkButton(
                key: ValueKey('share-${match.id}'),
                matchId: match.id,
                kind: ShareKind.match,
                shareTitle: 'vs ${match.opponent} · ${formatMatchDate(match.kickoffAt)}',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text('SQUAD', style: AppTextStyles.label(color: AppColors.textMuted)),
                  ),
                  Text(
                    '${players.length} players',
                    style: AppTextStyles.label(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                  borderRadius: AppRadius.lg,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < players.length; i++)
                      _RosterRow(
                        player: players[i],
                        isMe: players[i].profileId == userId,
                        showTopBorder: i > 0,
                      ),
                  ],
                ),
              ),
            ],
            // Any team admin can cancel (`delete_match`, 053).
            if (isManager) ...[
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => _confirmCancel(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent700),
                  child: Text(
                    'Cancel match',
                    style: AppTextStyles.title(size: 13, color: AppColors.accent700),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// This match's bill card, or — for admins in the Manager view — a prompt
/// to add one. Nothing for players until a bill exists.
class _MatchBill extends StatelessWidget {
  const _MatchBill({required this.matchId, required this.userId, required this.isManager});

  final String matchId;
  final String userId;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        final wallet = state.wallet;
        final walletMatch = wallet?.forMatch(matchId);
        if (wallet == null || walletMatch == null) return const SizedBox.shrink();
        final split = wallet.splitFor(walletMatch);
        final Widget card;
        if (split != null) {
          card = BillCard(
            walletMatch: walletMatch,
            split: split,
            userId: userId,
            isManager: isManager,
            canShare: false,
          );
        } else if (isManager) {
          card = AddBillCard(walletMatch: walletMatch, userId: userId);
        } else {
          return const SizedBox.shrink();
        }
        return Padding(padding: const EdgeInsets.only(top: 16), child: card);
      },
    );
  }
}

class _EmptyMatchday extends StatelessWidget {
  const _EmptyMatchday({
    required this.title,
    required this.body,
    required this.onAction,
    this.actionLabel,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.sports_soccer_rounded,
      title: title,
      body: body,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.teamName,
    required this.match,
    required this.isManager,
    required this.onEdit,
  });

  final String teamName;
  final match_entity.Match match;
  final bool isManager;
  final VoidCallback onEdit;

  static TextStyle get _titleStyle => AppTextStyles.body(
    size: 11,
    weight: FontWeight.w700,
    color: AppColors.teamGold,
  ).copyWith(letterSpacing: 1.4);

  static TextStyle get _editStyle => AppTextStyles.title(size: 11.5, color: AppColors.onDark);

  /// Whether "MATCHDAY HUB", the countdown chip and an "Edit details"
  /// button all fit in [maxWidth] at full length. When they don't, the
  /// button says "Edit" — the title and countdown are never cut short.
  static bool _fullEditLabelFits(BuildContext context, double maxWidth, DateTime kickoffAt) {
    final scaler = MediaQuery.textScalerOf(context);
    double width(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final title = width('MATCHDAY HUB', _titleStyle);
    // The chip: its label plus 10 padding and 1 border each side.
    final chip = width(_KickoffChip.labelFor(kickoffAt).$1, _KickoffChip.style(AppColors.teamGold)) + 22;
    // The button: its label plus 13 padding and 1 border each side.
    final button = width('Edit details', _editStyle) + 28;
    // 8 between title and chip, and at least 8 before the button.
    return title + 8 + chip + 8 + button <= maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final venueId = match.venueId;
    if (venueId == null) return _hero(context);
    return VenueBuilder(
      venueId: venueId,
      builder: (context, venue, reload) => _hero(context, venue: venue, reload: reload),
    );
  }

  /// The dark hero card; with a saved [venue]'s photo behind it, under a
  /// dark scrim so the light text reads on any photo.
  Widget _hero(BuildContext context, {Venue? venue, VoidCallback? reload}) {
    final venueName = match.venue;
    final photoUrl = venue?.photoUrl;
    return Container(
      decoration: AppDecorations.darkHero(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (photoUrl != null) ...[
            Positioned.fill(
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                // Fades in over the plain card; nothing if it fails.
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) => AnimatedOpacity(
                  opacity: frame == null && !wasSynchronouslyLoaded ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: child,
                ),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.neutral900.withValues(alpha: 0.62),
                      AppColors.neutral900.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(20),
            child: _content(context, venueName: venueName, venue: venue, reload: reload),
          ),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required String? venueName,
    required Venue? venue,
    required VoidCallback? reload,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // When it doesn't all fit, the button says just "Edit", so the
        // title and countdown keep their full text.
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              // Title and chip take all the free space (a Spacer beside a
              // Flexible title would take half of it and cut the title).
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'MATCHDAY HUB',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _titleStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _KickoffChip(kickoffAt: match.kickoffAt),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isManager)
                OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onDark,
                    side: const BorderSide(color: Color(0x47F9F4ED)),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    minimumSize: const Size(0, 28),
                  ),
                  child: Text(
                    _fullEditLabelFits(context, constraints.maxWidth, match.kickoffAt)
                        ? 'Edit details'
                        : 'Edit',
                    style: _editStyle,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: AppTextStyles.heading(size: 24, color: AppColors.onDark),
            children: [
              TextSpan(text: '$teamName '),
              TextSpan(
                text: 'vs',
                style: TextStyle(color: AppColors.onDarkMuted),
              ),
              TextSpan(text: ' ${match.opponent}'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 15, color: AppColors.teamGold),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${formatMatchDateTime(match.kickoffAt)} · ${formatPlayTime(match.durationMinutes)}',
                style: AppTextStyles.body(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: AppColors.onDark,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
        if (venueName != null)
          _VenueLine(
            match: match,
            name: venueName,
            isManager: isManager,
            venue: venue,
            onChanged: reload,
          ),
        if (venue case Venue(:final latitude?, :final longitude?))
          KickoffConditions(
            latitude: latitude,
            longitude: longitude,
            kickoffAt: match.kickoffAt,
            onDark: true,
            compact: true,
          ),
      ],
    );
  }
}

/// Where the match is. A saved venue (052) opens its details — photo,
/// notes, price, Google Maps; a typed one is just its name.
class _VenueLine extends StatelessWidget {
  const _VenueLine({
    required this.match,
    required this.name,
    required this.isManager,
    this.venue,
    this.onChanged,
  });

  final match_entity.Match match;
  final String name;
  final bool isManager;

  /// The saved venue, once loaded — for its Google Maps link.
  final Venue? venue;

  /// After its details were open (an admin may have edited it).
  final VoidCallback? onChanged;

  Future<void> _openMaps(BuildContext context, String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't open Google Maps.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueId = match.venueId;
    final style = AppTextStyles.body(
      size: 12.5,
      weight: FontWeight.w500,
      color: AppColors.onDarkMuted,
      height: 1.6,
    );
    if (venueId == null) return Text(name, style: style);
    final mapsUrl = venue?.mapsUrl;
    final nameLink = InkWell(
      onTap: () async {
        await showVenueDetails(
          context,
          venueId: venueId,
          canManage: isManager,
          kickoffAt: match.kickoffAt,
        );
        onChanged?.call();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, size: 15, color: AppColors.teamGold),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(
                color: AppColors.onDark,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.onDarkMuted,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.onDarkMuted),
        ],
      ),
    );
    if (mapsUrl == null) return nameLink;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Flexible(child: nameLink),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _openMaps(context, mapsUrl),
            icon: const Icon(Icons.directions_rounded, size: 16),
            label: Text(
              'Directions',
              style: AppTextStyles.title(size: 11.5, color: AppColors.onDark),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onDark,
              side: const BorderSide(color: Color(0x47F9F4ED)),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// How far off kickoff is — "TODAY", "IN 3 DAYS" — as a chip on the hub
/// header; gold while it's close, quiet once it's played.
class _KickoffChip extends StatelessWidget {
  const _KickoffChip({required this.kickoffAt});

  final DateTime kickoffAt;

  static TextStyle style(Color color) =>
      AppTextStyles.label(size: 11, color: color).copyWith(letterSpacing: 0.6);

  /// The chip's text, and whether kickoff is close (gold).
  static (String, bool) labelFor(DateTime kickoffAt) {
    final now = DateTime.now();
    final kickoff = kickoffAt.toLocal();
    final days = DateUtils.dateOnly(kickoff).difference(DateUtils.dateOnly(now)).inDays;
    final played = kickoff.isBefore(now);
    return switch (days) {
      0 when played => ('KICKED OFF', true),
      _ when played => ('PLAYED', false),
      0 => ('TODAY', true),
      1 => ('TOMORROW', true),
      _ => ('IN $days DAYS', days <= 3),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, soon) = labelFor(kickoffAt);
    final color = soon ? AppColors.teamGold : AppColors.onDarkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.pill,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: style(color),
      ),
    );
  }
}

/// The match RSVP as a Messenger-style poll. Until the viewer votes it
/// shows three options to pick from, then "Submit vote" — the options
/// slide in, and the card's glow pulses a few times to draw the eye. After
/// voting it shows results: each option with its voters' photos and a bar
/// filled to its share of the votes, plus "Change vote". Anyone on the
/// squad can vote in either view; the glow only runs when [urgent].
class _RsvpPoll extends StatefulWidget {
  const _RsvpPoll({
    required this.match,
    required this.roster,
    required this.userId,
    required this.myAnswer,
    required this.canVote,
    required this.urgent,
    required this.isSubmitting,
    required this.onRsvp,
  });

  final match_entity.Match match;
  final MatchdayLoaded roster;
  final RsvpAnswer? myAnswer;

  /// False if the viewer isn't on the squad.
  final bool canVote;

  /// Styles an unanswered vote as must-do (glow, "YOUR VOTE NEEDED") —
  /// anyone on the squad, before voting.
  final bool urgent;
  final bool isSubmitting;
  final ValueChanged<RsvpAnswer> onRsvp;

  /// The viewer — marked "(you)" in the voter list.
  final String userId;

  @override
  State<_RsvpPoll> createState() => _RsvpPollState();
}

class _RsvpPollState extends State<_RsvpPoll> with SingleTickerProviderStateMixin {
  static const _options = [
    (answer: RsvpAnswer.yes, label: "I'm in"),
    (answer: RsvpAnswer.maybe, label: 'Maybe'),
    (answer: RsvpAnswer.no, label: "I'm out"),
  ];

  /// Pulses the card's glow a few times while a vote is needed. Finite on
  /// purpose — an endless animation would keep the phone rendering (and
  /// never let widget tests settle).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _editing = false;

  /// The option picked but not yet submitted.
  RsvpAnswer? _pending;

  bool get _needsVote => widget.canVote && widget.myAnswer == null;
  bool get _urgent => widget.urgent && _needsVote;
  bool get _showOptions => _needsVote || (widget.canVote && _editing);

  @override
  void initState() {
    super.initState();
    _startPulse();
  }

  @override
  void didUpdateWidget(_RsvpPoll oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A vote landed (new or changed) — back to results.
    if (oldWidget.myAnswer != widget.myAnswer) {
      _editing = false;
      _pending = null;
    }
    _startPulse();
  }

  void _startPulse() {
    if (_urgent && !_pulse.isAnimating) {
      _pulse
        ..reset()
        ..repeat(reverse: true, count: 4);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roster = widget.roster;
    final votes = roster.players.length - roster.countOf(null);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = _urgent ? Curves.easeInOut.transform(_pulse.value) : 0.0;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.neutral200,
            borderRadius: AppRadius.xl,
            border: _urgent ? Border.all(color: AppColors.accent, width: 2) : null,
            boxShadow: [
              if (_urgent)
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.18 + 0.27 * glow),
                  blurRadius: 12 + 14 * glow,
                  spreadRadius: 1 + 2 * glow,
                ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.poll_rounded,
                  size: 18,
                  color: _urgent ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _urgent ? 'POLL · YOUR VOTE NEEDED' : 'POLL',
                    style: AppTextStyles.label(
                      color: _urgent ? AppColors.accent700 : AppColors.textMuted,
                    ),
                  ),
                ),
                Text(
                  '$votes of ${roster.players.length} voted',
                  style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Are you playing vs ${widget.match.opponent}?',
              style: AppTextStyles.title(size: 16),
            ),
            const SizedBox(height: 2),
            Text(
              [
                formatMatchDateTime(widget.match.kickoffAt),
                if (widget.match.playersNeeded case final needed?)
                  '${roster.countOf(RsvpAnswer.yes)} of $needed players in',
                if (_showOptions) 'Pick an option, then submit',
              ].join(' · '),
              style: AppTextStyles.body(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            for (final (index, option) in _options.indexed) ...[
              if (index > 0) SizedBox(height: _showOptions ? 6 : 10),
              if (_showOptions)
                _PollVoteOption(
                  // Keyed per mode so the slide-in replays when changing a vote.
                  key: ValueKey('vote-${option.answer}-$_editing'),
                  index: index,
                  label: option.label,
                  selected: (_pending ?? widget.myAnswer) == option.answer,
                  enabled: !widget.isSubmitting,
                  onTap: () => setState(() => _pending = option.answer),
                )
              else
                _PollResultBar(
                  label: option.label,
                  onShowVoters: () => _showPollVotersSheet(
                    context,
                    roster: roster,
                    userId: widget.userId,
                    initial: option.answer,
                  ),
                  teamSize: roster.players.length,
                  isMine: widget.myAnswer == option.answer,
                  voters: [
                    for (final player in roster.players)
                      if (player.answer == option.answer) player,
                  ],
                ),
            ],
            const SizedBox(height: 12),
            _footer(roster.countOf(null)),
          ],
        ),
      ),
    );
  }

  Widget _footer(int silent) {
    final muted = AppTextStyles.body(size: 12, weight: FontWeight.w600, color: AppColors.textMuted);
    if (_showOptions) {
      final pending = _pending;
      final canSubmit = pending != null && pending != widget.myAnswer && !widget.isSubmitting;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_urgent) ...[
            Text('Your squad is waiting on your vote to plan the lineup.', style: muted),
            const SizedBox(height: 8),
          ],
          _PollButton(
            label: widget.isSubmitting ? 'Submitting…' : 'Submit vote',
            primary: true,
            onPressed: canSubmit
                ? () {
                    HapticFeedback.mediumImpact();
                    widget.onRsvp(pending);
                  }
                : null,
          ),
          if (!_needsVote) ...[
            const SizedBox(height: 6),
            _PollButton(
              label: 'Cancel',
              onPressed: widget.isSubmitting
                  ? null
                  : () => setState(() {
                      _editing = false;
                      _pending = null;
                    }),
            ),
          ],
        ],
      );
    }
    final myAnswer = widget.myAnswer;
    if (!widget.canVote || myAnswer == null) {
      return Text(switch (silent) {
        0 => 'Everyone has voted.',
        1 => "1 hasn't voted yet",
        _ => "$silent haven't voted yet",
      }, style: muted);
    }
    final weekday = weekdayNames[widget.match.kickoffAt.toLocal().weekday - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(switch (myAnswer) {
          RsvpAnswer.yes => "You voted I'm in — see you $weekday!",
          RsvpAnswer.maybe => 'You voted Maybe',
          RsvpAnswer.no => "You voted I'm out",
        }, style: muted),
        const SizedBox(height: 8),
        _PollButton(label: 'Change vote', onPressed: () => setState(() => _editing = true)),
      ],
    );
  }
}

/// The poll's full-width light button ("Change vote" / "Cancel").
class _PollButton extends StatelessWidget {
  const _PollButton({required this.label, required this.onPressed, this.primary = false});

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// "Submit vote" is filled with the accent colour; the rest are light.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = primary ? AppColors.accent : AppColors.card;
    final foreground = primary ? AppColors.onDark : AppColors.text;
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          disabledBackgroundColor: background.withValues(alpha: 0.45),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            size: 14,
            weight: FontWeight.w700,
            color: enabled ? foreground : foreground.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// One tappable poll option — slides in on appear, staggered by [index].
class _PollVoteOption extends StatelessWidget {
  const _PollVoteOption({
    super.key,
    required this.index,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 110),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          // Picked: a warm tint and accent outline fade in.
          color: selected ? AppColors.accent100 : AppColors.card,
          borderRadius: AppRadius.md,
          border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: 2),
          boxShadow: selected ? AppShadows.subtle : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.md,
            onTap: enabled
                ? () {
                    if (!selected) HapticFeedback.selectionClick();
                    onTap();
                  }
                : null,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.accent : Colors.transparent,
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.text.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    // The tick pops in rather than appearing.
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              key: ValueKey('tick'),
                              size: 14,
                              color: AppColors.onDark,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTextStyles.body(
                      size: 14,
                      weight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.accent800 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One poll result, Messenger-style: the option with its voters' photos
/// and percentage on the right, and a bar underneath filled (animating in)
/// to that percentage — of the whole team, not just those who voted, so
/// "In" reads as how much of the squad is confirmed.
class _PollResultBar extends StatelessWidget {
  const _PollResultBar({
    required this.label,
    required this.onShowVoters,
    required this.teamSize,
    required this.isMine,
    required this.voters,
  });

  final String label;

  /// Opens the list of who voted (tap the row or the voter photos).
  final VoidCallback onShowVoters;
  final int teamSize;
  final bool isMine;
  final List<MatchdayPlayer> voters;

  @override
  Widget build(BuildContext context) {
    final share = teamSize == 0 ? 0.0 : voters.length / teamSize;
    return Semantics(
      label: '$label: ${voters.length} of $teamSize players${isMine ? ', your vote' : ''}',
      button: true,
      hint: 'Show who voted',
      child: InkWell(
        onTap: onShowVoters,
        borderRadius: AppRadius.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body(
                      size: 14,
                      weight: isMine ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (isMine) ...[
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                ],
                _VoterStack(voters: voters),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(share * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: AppRadius.pill,
              child: SizedBox(
                height: 8,
                child: ColoredBox(
                  color: AppColors.neutral300,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: share),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: value == 0
                          ? const SizedBox.shrink()
                          : FractionallySizedBox(
                              widthFactor: value,
                              heightFactor: 1,
                              // A few pixels minimum, so one vote still shows.
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 8),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: AppRadius.pill,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to two overlapping voter photos (initials when there's no photo),
/// then a "+N" pill for the rest.
class _VoterStack extends StatelessWidget {
  const _VoterStack({required this.voters});

  final List<MatchdayPlayer> voters;

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final initials = words.take(2).map((word) => word[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    if (voters.isEmpty) return const SizedBox(height: 22);
    final shown = voters.take(2).toList();
    final extra = voters.length - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22.0 + (shown.length - 1) * 14,
          height: 22,
          child: Stack(
            children: [
              for (final (index, voter) in shown.indexed)
                Positioned(
                  left: index * 14,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(color: AppColors.neutral200, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 9.5,
                      backgroundColor: AppColors.neutral400,
                      foregroundImage: voter.avatarUrl == null
                          ? null
                          : NetworkImage(voter.avatarUrl!),
                      onForegroundImageError: voter.avatarUrl == null ? null : (_, _) {},
                      child: Text(
                        _initials(voter.name),
                        style: AppTextStyles.body(
                          size: 7.5,
                          weight: FontWeight.w800,
                          color: AppColors.onDark,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0)
          Container(
            margin: const EdgeInsets.only(left: 2),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.pill),
            child: Text('+$extra', style: AppTextStyles.body(size: 11, weight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.player, required this.isMe, required this.showTopBorder});

  final MatchdayPlayer player;
  final bool isMe;
  final bool showTopBorder;

  Color get _dotColor => switch (player.answer) {
    RsvpAnswer.yes => AppColors.accent2_700,
    RsvpAnswer.maybe => AppColors.teamGold,
    RsvpAnswer.no => AppColors.text.withValues(alpha: 0.25),
    null => AppColors.neutral400,
  };

  String get _statusLabel => switch (player.answer) {
    RsvpAnswer.yes => 'In',
    RsvpAnswer.maybe => 'Maybe',
    RsvpAnswer.no => 'Out',
    null => 'No reply yet',
  };

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
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${player.name} (you)' : player.name,
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusLabel,
                  style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.textMuted,
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

/// Who voted what: a chip per answer (plus "No reply") with its count,
/// starting on [initial], and a list of those players with photo and name.
Future<void> _showPollVotersSheet(
  BuildContext context, {
  required MatchdayLoaded roster,
  required String userId,
  required RsvpAnswer initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => _PollVotersSheet(roster: roster, userId: userId, initial: initial),
  );
}

class _PollVotersSheet extends StatefulWidget {
  const _PollVotersSheet({required this.roster, required this.userId, required this.initial});

  final MatchdayLoaded roster;
  final String userId;
  final RsvpAnswer initial;

  @override
  State<_PollVotersSheet> createState() => _PollVotersSheetState();
}

class _PollVotersSheetState extends State<_PollVotersSheet> {
  static const _tabs = [
    (answer: RsvpAnswer.yes, label: "I'm in"),
    (answer: RsvpAnswer.maybe, label: 'Maybe'),
    (answer: RsvpAnswer.no, label: "I'm out"),
    (answer: null, label: 'No reply'),
  ];

  late RsvpAnswer? _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final players = widget.roster.players;
    final shown = [
      for (final player in players)
        if (player.answer == _selected) player,
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Votes', style: AppTextStyles.title(size: 18)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in _tabs) ...[
                    ChoiceChip(
                      label: Text('${tab.label} · ${widget.roster.countOf(tab.answer)}'),
                      selected: _selected == tab.answer,
                      onSelected: (_) => setState(() => _selected = tab.answer),
                      selectedColor: AppColors.neutral900,
                      labelStyle: AppTextStyles.body(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: _selected == tab.answer ? AppColors.onDark : AppColors.text,
                      ),
                      showCheckmark: false,
                      shape: const StadiumBorder(),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No one yet',
                          style: AppTextStyles.body(size: 13, color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final player = shown[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: PlayerAvatar(player: player, radius: 20),
                          title: Text(
                            player.profileId == widget.userId
                                ? '${player.name} (you)'
                                : player.name,
                            style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admins' "Remind players to vote": one push to everyone who hasn't
/// answered, once per day per match (`nudge_match_rsvp` enforces it too).
class _RemindPlayersButton extends StatelessWidget {
  const _RemindPlayersButton({required this.match, required this.silent});

  final match_entity.Match match;

  /// How many haven't answered yet.
  final int silent;

  @override
  Widget build(BuildContext context) {
    final last = match.lastNudgedAt?.toLocal();
    final now = DateTime.now();
    final remindedToday =
        last != null && last.year == now.year && last.month == now.month && last.day == now.day;
    return BlocBuilder<MatchBloc, MatchState>(
      builder: (context, state) {
        final busy = state is MatchSubmitting;
        return SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton.icon(
            onPressed: remindedToday || busy
                ? null
                : () => context.read<MatchBloc>().add(MatchNudgeRequested(match.id)),
            icon: Icon(
              remindedToday ? Icons.check_rounded : Icons.notifications_active_rounded,
              size: 18,
            ),
            label: Text(
              remindedToday
                  ? 'Reminded today at ${formatMatchTime(last)}'
                  : 'Remind players to vote ($silent haven\'t answered)',
              style: AppTextStyles.body(size: 13, weight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
              shape: const StadiumBorder(),
            ),
          ),
        );
      },
    );
  }
}
