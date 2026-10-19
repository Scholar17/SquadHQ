import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../match/presentation/bloc/match_bloc.dart';
import '../../match/presentation/bloc/match_event.dart';
import '../../match/presentation/bloc/match_history_bloc.dart';
import '../../match/presentation/bloc/match_state.dart';
import '../../match/presentation/pages/past_match_page.dart';
import '../../squad/presentation/bloc/squad_ledger_bloc.dart';
import '../../team_membership/domain/entities/team.dart';
import '../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../team_membership/presentation/bloc/team_membership_event.dart';
import '../../team_membership/presentation/bloc/team_membership_state.dart';
import '../domain/entities/app_notification.dart';
import 'bloc/notification_bloc.dart';

/// Opens what [notification] is about: marks it read, then [openTarget].
Future<void> openNotification(
  BuildContext context,
  AppNotification notification, {
  required String userId,
}) {
  context.read<NotificationBloc>().add(NotificationOpened(notification.id));
  return openTarget(
    context,
    target: notification.target,
    teamId: notification.teamId,
    matchId: notification.matchId,
    expenseId: notification.expenseId,
    tripId: notification.tripId,
    unknownKind: notification.kind == NotificationKind.other,
    userId: userId,
  );
}

/// Opens [target] — a notification's, or a share link's: switches to
/// [teamId] if that isn't the active team, then shows its match (detail
/// screen while upcoming, past-match screen once played) or the Wallet
/// tab. [unknownKind]: a notification kind this version doesn't know.
Future<void> openTarget(
  BuildContext context, {
  required NotificationTarget target,
  required String? teamId,
  String? matchId,
  String? expenseId,
  String? tripId,
  bool unknownKind = false,
  required String userId,
}) async {
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final membershipBloc = context.read<TeamMembershipBloc>();
  final matchBloc = context.read<MatchBloc>();
  final historyBloc = context.read<MatchHistoryBloc>();
  final squadBloc = context.read<SquadLedgerBloc>();

  void say(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  void unavailable(String location) {
    router.go(location);
    say('This match is no longer available.');
  }

  final activated = await _activateTeam(
    target == NotificationTarget.squad
        ? _footballTeamFor(teamId, membershipBloc.state)
        : teamId,
    membershipBloc: membershipBloc,
    matchBloc: matchBloc,
    historyBloc: historyBloc,
    squadBloc: squadBloc,
  );
  if (activated == null) {
    // Left (or removed from) the group it's about.
    router.go(AppRoutes.home);
    say("You're no longer in this group.");
    return;
  }
  final team = activated.team;
  // It was about another group: say so, rather than silently swapping the
  // whole app over.
  if (activated.switched) say('Switched to ${team.name}');
  final isManager = team.role != TeamRole.player;

  Future<void> openPast() => navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => PastMatchPage(
        matchId: matchId!,
        teamName: team.name,
        userId: userId,
        isManager: isManager,
      ),
    ),
  );
  bool upcoming() => matchId != null && _upcomingMatchIds(matchBloc.state).contains(matchId);
  bool past() =>
      matchId != null &&
      (historyBloc.state.history?.matches.any((past) => past.match.id == matchId) ?? false);
  // Not in what's loaded: the push may be newer than this screen's data
  // (the app was asleep when the match was made or played). Reload once
  // before calling it gone.
  if (matchId != null && !upcoming() && !past()) {
    final matchesDone = Completer<void>();
    final historyDone = Completer<void>();
    matchBloc.add(MatchRefreshRequested(done: matchesDone));
    historyBloc.add(MatchHistoryStarted(done: historyDone));
    try {
      await (matchesDone.future, historyDone.future).wait.timeout(const Duration(seconds: 10));
    } on Object {
      // Slow network: go with what's there.
    }
  }
  final isUpcoming = upcoming();
  final isPast = past();

  switch (target) {
    case NotificationTarget.group:
      router.go(AppRoutes.home);
    // A squad's Settle tab is the Wallet slot (see GroupTab).
    case NotificationTarget.wallet || NotificationTarget.settle:
      router.go(AppRoutes.wallet);
    case NotificationTarget.squad:
      router.go(AppRoutes.squad);
    case NotificationTarget.expense:
      // Not in the loaded ledger (added while the app was asleep, or since
      // deleted): reload once, as for matches — the detail screen would
      // otherwise wait on it forever.
      if (expenseId != null && squadBloc.state.ledger?.expense(expenseId) == null) {
        final done = Completer<void>();
        squadBloc.add(SquadRefreshRequested(done: done));
        try {
          await done.future.timeout(const Duration(seconds: 10));
        } on Object {
          // Slow network: go with what's there.
        }
      }
      if (expenseId == null || squadBloc.state.ledger?.expense(expenseId) == null) {
        // The squad's Expenses tab is the Match slot (see GroupTab).
        router.go(AppRoutes.match);
        say('This expense was deleted.');
      } else {
        unawaited(router.push(AppRoutes.expenseDetail(expenseId)));
      }
    case NotificationTarget.trip:
      if (tripId == null) {
        router.go(AppRoutes.home);
      } else {
        unawaited(router.push(AppRoutes.trip(tripId)));
      }
    // A kind this version doesn't know yet, not about a match: Home,
    // rather than a "match no longer available" that isn't true.
    case NotificationTarget.match
        when matchId == null && unknownKind:
      router.go(AppRoutes.home);
    case NotificationTarget.match when isUpcoming:
      unawaited(
        router.push(
          AppRoutes.upcomingMatch,
          extra: UpcomingMatchArgs(
            // isUpcoming means it's there.
            matchId: matchId!,
            teamName: team.name,
            userId: userId,
            isManager: isManager,
          ),
        ),
      );
    case NotificationTarget.match || NotificationTarget.pastMatch when isPast:
      unawaited(openPast());
    case NotificationTarget.match:
      unavailable(AppRoutes.match);
    case NotificationTarget.pastMatch:
      unavailable(AppRoutes.home);
  }
}

Set<String> _upcomingMatchIds(MatchState state) => switch (state) {
  MatchLoaded(:final matches) => {for (final match in matches) match.id},
  MatchSubmitting(:final previous) || MatchFailure(:final previous) => _upcomingMatchIds(previous),
  _ => const {},
};

/// Where a rating notification opens: ratings are football, so [teamId]
/// if it's a football team, else (one filed under an expense squad before
/// 050_rating_pushes_football_only.sql) the active football team, or any.
/// [teamId] as it was if you're in no football team.
String? _footballTeamFor(String? teamId, TeamMembershipState state) {
  final football = _teams(state).where((team) => !team.isSquad).toList();
  if (football.any((team) => team.id == teamId)) return teamId;
  return (football.where((team) => team.isActive).firstOrNull ?? football.firstOrNull)?.id ??
      teamId;
}

List<Team> _teams(TeamMembershipState state) => switch (state) {
  TeamMembershipLoaded(:final teams) => teams,
  TeamMembershipSubmitting(:final previous) ||
  TeamMembershipFailure(:final previous) => _teams(previous),
  _ => const [],
};

/// [teamId]'s group — switched to (and its data loaded) if it wasn't the
/// active one; [switched] says whether it was. The active group if
/// [teamId] is null; null if the player isn't in that group any more.
Future<({Team team, bool switched})?> _activateTeam(
  String? teamId, {
  required TeamMembershipBloc membershipBloc,
  required MatchBloc matchBloc,
  required MatchHistoryBloc historyBloc,
  required SquadLedgerBloc squadBloc,
}) async {
  final teams = _teams(membershipBloc.state);
  final team = teams
      .where((team) => teamId == null ? team.isActive : team.id == teamId)
      .firstOrNull;
  if (team == null) return null;
  if (team.isActive) return (team: team, switched: false);

  const wait = Duration(seconds: 10);
  // Subscribed before switching, so the new group's loads can't be missed.
  // Only a switch shows Loading (refreshes are quiet), so the Loaded after
  // it is the new group's, not a refresh of the old one. A football team
  // needs its matches; an expense squad its ledger (expenses, trips).
  final Future<Object?> loaded = team.isSquad
      ? squadBloc.stream
            .skipWhile((state) => state is! SquadLedgerLoading)
            .firstWhere((state) => state is SquadLedgerLoaded || state is SquadLedgerFailure)
            .timeout(wait)
      : (
          matchBloc.stream
              .skipWhile((state) => state is! MatchLoading)
              .firstWhere((state) => state is MatchLoaded)
              .timeout(wait),
          historyBloc.stream
              .skipWhile((state) => state is! MatchHistoryLoading)
              .firstWhere((state) => state is MatchHistoryLoaded)
              .timeout(wait),
        ).wait;
  membershipBloc.add(TeamSwitchRequested(team.id));
  try {
    await loaded;
  } on Object {
    // Slow network: open with what's there; the screens load on their own.
  }
  return (team: team, switched: true);
}
