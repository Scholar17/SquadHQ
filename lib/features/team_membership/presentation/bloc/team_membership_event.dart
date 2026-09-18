import 'package:equatable/equatable.dart';

sealed class TeamMembershipEvent extends Equatable {
  const TeamMembershipEvent();

  @override
  List<Object?> get props => [];
}

/// Loads whatever teams the signed-in profile already belongs to, if any.
final class TeamMembershipStarted extends TeamMembershipEvent {
  const TeamMembershipStarted();
}

final class TeamCreateRequested extends TeamMembershipEvent {
  const TeamCreateRequested(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class TeamJoinRequested extends TeamMembershipEvent {
  const TeamJoinRequested(this.inviteCode);

  final String inviteCode;

  @override
  List<Object?> get props => [inviteCode];
}

final class TeamSwitchRequested extends TeamMembershipEvent {
  const TeamSwitchRequested(this.teamId);

  final String teamId;

  @override
  List<Object?> get props => [teamId];
}
