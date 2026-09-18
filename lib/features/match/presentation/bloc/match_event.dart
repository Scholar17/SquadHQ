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

final class MatchCreateRequested extends MatchEvent {
  const MatchCreateRequested({
    required this.teamId,
    required this.opponent,
    required this.kickoffAt,
    this.venue,
    this.feePerPlayer,
  });

  final String teamId;
  final String opponent;
  final DateTime kickoffAt;
  final String? venue;
  final double? feePerPlayer;

  @override
  List<Object?> get props => [teamId, opponent, kickoffAt, venue, feePerPlayer];
}
