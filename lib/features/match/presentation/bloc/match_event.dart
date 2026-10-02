import 'package:equatable/equatable.dart';

sealed class MatchEvent extends Equatable {
  const MatchEvent();

  @override
  List<Object?> get props => [];
}

/// Fired whenever the active team changes (including to/from no team at
/// all) — reloads the next match for [teamId], or clears it when null.
final class MatchTeamSelected extends MatchEvent {
  const MatchTeamSelected(this.teamId);

  final String? teamId;

  @override
  List<Object?> get props => [teamId];
}

/// Reloads the current team's matches quietly (no spinner) — the shell's
/// periodic refresh, so a match that kicks off leaves the upcoming list.
final class MatchRefreshRequested extends MatchEvent {
  const MatchRefreshRequested();
}

final class MatchCreateRequested extends MatchEvent {
  const MatchCreateRequested({
    required this.teamId,
    required this.opponent,
    required this.kickoffAt,
    this.venue,
    required this.durationMinutes,
    this.playersNeeded,
  });

  final String teamId;
  final String opponent;
  final DateTime kickoffAt;
  final String? venue;
  final int durationMinutes;
  final int? playersNeeded;

  @override
  List<Object?> get props => [teamId, opponent, kickoffAt, venue, durationMinutes, playersNeeded];
}

/// Admin-only edit of an existing match — see `update_match` in
/// supabase/sql/007_match_rsvps_and_actions.sql.
final class MatchUpdateRequested extends MatchEvent {
  const MatchUpdateRequested({
    required this.matchId,
    required this.opponent,
    required this.kickoffAt,
    this.venue,
    required this.durationMinutes,
    this.playersNeeded,
  });

  final String matchId;
  final String opponent;
  final DateTime kickoffAt;
  final String? venue;
  final int durationMinutes;
  final int? playersNeeded;

  @override
  List<Object?> get props => [matchId, opponent, kickoffAt, venue, durationMinutes, playersNeeded];
}

/// Admin-only "Remind players to vote", once per day per match.
final class MatchNudgeRequested extends MatchEvent {
  const MatchNudgeRequested(this.matchId);

  final String matchId;

  @override
  List<Object?> get props => [matchId];
}

/// Admin-only cancel — deletes the match along with its RSVPs.
final class MatchDeleteRequested extends MatchEvent {
  const MatchDeleteRequested(this.matchId);

  final String matchId;

  @override
  List<Object?> get props => [matchId];
}
