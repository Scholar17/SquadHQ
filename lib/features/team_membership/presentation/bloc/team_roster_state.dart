import 'package:equatable/equatable.dart';

import '../../domain/entities/team_member.dart';

sealed class TeamRosterState extends Equatable {
  const TeamRosterState();

  @override
  List<Object?> get props => [];
}

final class TeamRosterLoading extends TeamRosterState {
  const TeamRosterLoading();
}

final class TeamRosterLoaded extends TeamRosterState {
  const TeamRosterLoaded(this.members);

  final List<TeamMember> members;

  @override
  List<Object?> get props => [members];
}

/// A promote/demote/delete submission is in flight; [previous] is what to
/// fall back to (always [TeamRosterLoaded] in practice).
final class TeamRosterSubmitting extends TeamRosterState {
  const TeamRosterSubmitting(this.previous);

  final TeamRosterState previous;

  @override
  List<Object?> get props => [previous];
}

final class TeamRosterFailure extends TeamRosterState {
  const TeamRosterFailure(this.message, this.previous);

  final String message;
  final TeamRosterState previous;

  @override
  List<Object?> get props => [message, previous];
}

/// Terminal — the team was deleted. The page reacts by refreshing the
/// global [TeamMembershipBloc] and popping itself.
final class TeamRosterTeamDeleted extends TeamRosterState {
  const TeamRosterTeamDeleted();
}
