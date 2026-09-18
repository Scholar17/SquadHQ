import 'package:equatable/equatable.dart';

sealed class TeamRosterEvent extends Equatable {
  const TeamRosterEvent();

  @override
  List<Object?> get props => [];
}

final class TeamRosterStarted extends TeamRosterEvent {
  const TeamRosterStarted();
}

final class TeamRosterPromoteRequested extends TeamRosterEvent {
  const TeamRosterPromoteRequested(this.profileId);

  final String profileId;

  @override
  List<Object?> get props => [profileId];
}

final class TeamRosterDemoteRequested extends TeamRosterEvent {
  const TeamRosterDemoteRequested(this.profileId);

  final String profileId;

  @override
  List<Object?> get props => [profileId];
}

final class TeamRosterDeleteTeamRequested extends TeamRosterEvent {
  const TeamRosterDeleteTeamRequested();
}
