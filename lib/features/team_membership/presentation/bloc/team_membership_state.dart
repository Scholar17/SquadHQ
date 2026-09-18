import 'package:equatable/equatable.dart';

import '../../domain/entities/team.dart';

sealed class TeamMembershipState extends Equatable {
  const TeamMembershipState();

  @override
  List<Object?> get props => [];
}

final class TeamMembershipLoading extends TeamMembershipState {
  const TeamMembershipLoading();
}

/// The profile's teams (0-3). Empty means it isn't on one yet.
final class TeamMembershipLoaded extends TeamMembershipState {
  const TeamMembershipLoaded(this.teams);

  final List<Team> teams;

  static const maxTeams = 3;

  @override
  List<Object?> get props => [teams];
}

/// A create/join/switch submission is in flight; [previous] is what to
/// fall back to (always [TeamMembershipLoaded] in practice).
final class TeamMembershipSubmitting extends TeamMembershipState {
  const TeamMembershipSubmitting(this.previous);

  final TeamMembershipState previous;

  @override
  List<Object?> get props => [previous];
}

final class TeamMembershipFailure extends TeamMembershipState {
  const TeamMembershipFailure(this.message, this.previous);

  final String message;
  final TeamMembershipState previous;

  @override
  List<Object?> get props => [message, previous];
}
