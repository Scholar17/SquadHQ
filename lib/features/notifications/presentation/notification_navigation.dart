import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../match/presentation/bloc/match_bloc.dart';
import '../../match/presentation/bloc/match_history_bloc.dart';
import '../../match/presentation/bloc/match_state.dart';
import '../../match/presentation/pages/past_match_page.dart';
import '../../team_membership/domain/entities/team.dart';
import '../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../team_membership/presentation/bloc/team_membership_event.dart';
import '../../team_membership/presentation/bloc/team_membership_state.dart';
import '../domain/entities/app_notification.dart';
import 'bloc/notification_bloc.dart';

/// Opens what [notification] is about: marks it read, switches to its team
/// if that isn't the active one, then shows its match (detail screen while
/// upcoming, past-match screen once played) or the Wallet tab.
Future<void> openNotification(
  BuildContext context,
  AppNotification notification, {
  required String userId,
  required bool adminViewIsManager,
}) async {
  context.read<NotificationBloc>().add(NotificationOpened(notification.id));
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final membershipBloc = context.read<TeamMembershipBloc>();
  final matchBloc = context.read<MatchBloc>();
  final historyBloc = context.read<MatchHistoryBloc>();

  void unavailable(String location) {
    router.go(location);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('This match is no longer available.')));
  }

  final team = await _activateTeam(
    notification.teamId,
    membershipBloc: membershipBloc,
    matchBloc: matchBloc,
    historyBloc: historyBloc,
  );
  if (team == null) {
    unavailable(AppRoutes.home);
    return;
  }
  final isManager = team.role != TeamRole.player && adminViewIsManager;
  final matchId = notification.matchId;

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
  final isUpcoming =
      matchId != null && _upcomingMatchIds(matchBloc.state).contains(matchId);
  final isPast = matchId != null &&
      (historyBloc.state.history?.matches.any((past) => past.match.id == matchId) ?? false);

  switch (notification.target) {
    // A squad's Settle tab is the Wallet slot (see GroupTab).
    case NotificationTarget.wallet || NotificationTarget.settle:
      router.go(AppRoutes.wallet);
    case NotificationTarget.expense:
      final expenseId = notification.expenseId;
      if (expenseId == null) {
        unavailable(AppRoutes.match);
      } else {
        unawaited(router.push(AppRoutes.expenseDetail(expenseId)));
      }
    case NotificationTarget.match when isUpcoming:
      unawaited(
        router.push(
          AppRoutes.upcomingMatch,
          extra: UpcomingMatchArgs(
            matchId: matchId,
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
      MatchSubmitting(:final previous) || MatchFailure(:final previous) =>
        _upcomingMatchIds(previous),
      _ => const {},
    };

List<Team> _teams(TeamMembershipState state) => switch (state) {
      TeamMembershipLoaded(:final teams) => teams,
      TeamMembershipSubmitting(:final previous) || TeamMembershipFailure(:final previous) =>
        _teams(previous),
      _ => const [],
    };

/// [teamId]'s team — switched to and with its matches loaded, if it wasn't
/// the active one. The active team if [teamId] is null; null if the player
/// isn't on that team any more.
Future<Team?> _activateTeam(
  String? teamId, {
  required TeamMembershipBloc membershipBloc,
  required MatchBloc matchBloc,
  required MatchHistoryBloc historyBloc,
}) async {
  final teams = _teams(membershipBloc.state);
  final team = teams.where((team) => teamId == null ? team.isActive : team.id == teamId).firstOrNull;
  if (team == null || team.isActive) return team;

  const wait = Duration(seconds: 10);
  // Subscribed before switching, so the new team's loads can't be missed.
  // Only a team switch shows Loading (refreshes are quiet), so the Loaded
  // after it is the new team's, not a refresh of the old one.
  final matchesLoaded = matchBloc.stream
      .skipWhile((state) => state is! MatchLoading)
      .firstWhere((state) => state is MatchLoaded)
      .timeout(wait);
  final historyLoaded = historyBloc.stream
      .skipWhile((state) => state is! MatchHistoryLoading)
      .firstWhere((state) => state is MatchHistoryLoaded)
      .timeout(wait);
  membershipBloc.add(TeamSwitchRequested(team.id));
  try {
    await (matchesLoaded, historyLoaded).wait;
  } on Object {
    // Slow network: open with what's there; the screens load on their own.
  }
  return team;
}
