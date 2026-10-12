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

/// A quiet reload (no Loading in between), e.g. after a change on the
/// server.
final class TeamMembershipRefreshRequested extends TeamMembershipEvent {
  const TeamMembershipRefreshRequested();
}

/// [newOwnerId]: who becomes super admin, when the super admin leaves.
/// [done] gets the error message, or null once left.
final class TeamLeaveRequested extends TeamMembershipEvent {
  const TeamLeaveRequested(this.teamId, {this.newOwnerId, this.done});

  final String teamId;
  final String? newOwnerId;
  final void Function(String? error)? done;

  @override
  List<Object?> get props => [teamId, newOwnerId];
}

/// [done] gets the error message, or null once removed.
final class TeamMemberRemoveRequested extends TeamMembershipEvent {
  const TeamMemberRemoveRequested({required this.teamId, required this.profileId, this.done});

  final String teamId;
  final String profileId;
  final void Function(String? error)? done;

  @override
  List<Object?> get props => [teamId, profileId];
}
