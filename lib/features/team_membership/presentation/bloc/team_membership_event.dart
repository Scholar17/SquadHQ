import 'package:equatable/equatable.dart';

import '../../domain/entities/team.dart';

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
  const TeamCreateRequested(
    this.name, {
    this.kind = GroupKind.team,
    this.currency = GroupCurrency.thb,
  });

  final String name;
  final GroupKind kind;
  final GroupCurrency currency;

  @override
  List<Object?> get props => [name, kind, currency];
}

final class TeamJoinRequested extends TeamMembershipEvent {
  const TeamJoinRequested(this.inviteCode);

  final String inviteCode;

  @override
  List<Object?> get props => [inviteCode];
}

final class TeamTimezoneChangeRequested extends TeamMembershipEvent {
  const TeamTimezoneChangeRequested({required this.teamId, required this.timezone});

  final String teamId;
  final String timezone;

  @override
  List<Object?> get props => [teamId, timezone];
}

final class TeamSwitchRequested extends TeamMembershipEvent {
  const TeamSwitchRequested(this.teamId);

  final String teamId;

  @override
  List<Object?> get props => [teamId];
}
