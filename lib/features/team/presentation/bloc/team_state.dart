import 'package:equatable/equatable.dart';

import '../../domain/entities/team_snapshot.dart';

sealed class TeamState extends Equatable {
  const TeamState();

  @override
  List<Object?> get props => [];
}

final class TeamLoading extends TeamState {
  const TeamLoading();
}

final class TeamError extends TeamState {
  const TeamError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class TeamLoaded extends TeamState {
  const TeamLoaded({
    required this.snapshot,
    required this.role,
    required this.myRsvp,
  });

  final TeamSnapshot snapshot;
  final SquadRole role;
  final RsvpStatus myRsvp;

  bool get isManager => role == SquadRole.manager;

  TeamLoaded copyWith({SquadRole? role, RsvpStatus? myRsvp}) => TeamLoaded(
        snapshot: snapshot,
        role: role ?? this.role,
        myRsvp: myRsvp ?? this.myRsvp,
      );

  @override
  List<Object?> get props => [snapshot, role, myRsvp];
}
