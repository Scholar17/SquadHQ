import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/team_snapshot.dart';
import '../../domain/repositories/team_repository.dart';
import 'team_event.dart';
import 'team_state.dart';

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  TeamBloc(this._repository) : super(const TeamLoading()) {
    on<TeamStarted>(_onStarted);
    on<TeamRoleToggled>(_onRoleToggled);
    on<TeamMyRsvpChanged>(_onMyRsvpChanged);
    on<TeamMatchDetailsUpdated>(_onMatchDetailsUpdated);
  }

  final TeamRepository _repository;

  Future<void> _onStarted(TeamStarted event, Emitter<TeamState> emit) async {
    emit(const TeamLoading());
    final result = await _repository.getTeamSnapshot();
    result.fold(
      (failure) => emit(TeamError(failure.message)),
      (snapshot) => emit(
        TeamLoaded(
          snapshot: snapshot,
          role: SquadRole.manager,
          myRsvp: RsvpStatus.pending,
        ),
      ),
    );
  }

  void _onRoleToggled(TeamRoleToggled event, Emitter<TeamState> emit) {
    final current = state;
    if (current is! TeamLoaded) return;
    emit(
      current.copyWith(
        role: current.role == SquadRole.manager
            ? SquadRole.player
            : SquadRole.manager,
      ),
    );
  }

  void _onMyRsvpChanged(TeamMyRsvpChanged event, Emitter<TeamState> emit) {
    final current = state;
    if (current is! TeamLoaded) return;
    emit(current.copyWith(myRsvp: event.status));
  }

  void _onMatchDetailsUpdated(
    TeamMatchDetailsUpdated event,
    Emitter<TeamState> emit,
  ) {
    final current = state;
    if (current is! TeamLoaded) return;
    final match = current.snapshot.match.copyWith(
      opponent: event.opponent,
      kickoffLabel: event.kickoffLabel,
      venueLine: event.venueLine,
      feePerPlayer: event.feePerPlayer,
      kit: event.kit,
      hubLine1: 'Kickoff ${event.kickoffLabel} at ${event.venueLine}.',
      hubLine2:
          'RSVP ${current.snapshot.match.rsvpClosesLabel.toLowerCase()} — ${current.snapshot.match.confirmedOf} confirmed so far.',
    );
    emit(
      TeamLoaded(
        snapshot: current.snapshot.copyWith(match: match),
        role: current.role,
        myRsvp: current.myRsvp,
      ),
    );
  }
}
