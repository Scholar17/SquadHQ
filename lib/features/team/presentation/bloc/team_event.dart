import 'package:equatable/equatable.dart';

import '../../domain/entities/team_snapshot.dart';

sealed class TeamEvent extends Equatable {
  const TeamEvent();

  @override
  List<Object?> get props => [];
}

final class TeamStarted extends TeamEvent {
  const TeamStarted();
}

final class TeamRoleToggled extends TeamEvent {
  const TeamRoleToggled();
}

/// The signed-in player's own RSVP — separate from the roster, which
/// represents everyone else on the team.
final class TeamMyRsvpChanged extends TeamEvent {
  const TeamMyRsvpChanged(this.status);

  final RsvpStatus status;

  @override
  List<Object?> get props => [status];
}

/// Manager-only edit from the matchday hub's "Edit details" button.
final class TeamMatchDetailsUpdated extends TeamEvent {
  const TeamMatchDetailsUpdated({
    required this.opponent,
    required this.kickoffLabel,
    required this.venueLine,
    required this.feePerPlayer,
    required this.kit,
  });

  final String opponent;
  final String kickoffLabel;
  final String venueLine;
  final String feePerPlayer;
  final String kit;

  @override
  List<Object?> get props => [opponent, kickoffLabel, venueLine, feePerPlayer, kit];
}
