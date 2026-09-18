import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/create_team.dart';
import '../../domain/usecases/get_my_teams.dart';
import '../../domain/usecases/join_team.dart';
import '../../domain/usecases/switch_active_team.dart';
import 'team_membership_event.dart';
import 'team_membership_state.dart';

class TeamMembershipBloc
    extends Bloc<TeamMembershipEvent, TeamMembershipState> {
  TeamMembershipBloc({
    required CreateTeam createTeam,
    required JoinTeam joinTeam,
    required GetMyTeams getMyTeams,
    required SwitchActiveTeam switchActiveTeam,
  })  : _createTeam = createTeam,
        _joinTeam = joinTeam,
        _getMyTeams = getMyTeams,
        _switchActiveTeam = switchActiveTeam,
        super(const TeamMembershipLoading()) {
    on<TeamMembershipStarted>(_onStarted);
    on<TeamCreateRequested>(_onCreateRequested);
    on<TeamJoinRequested>(_onJoinRequested);
    on<TeamSwitchRequested>(_onSwitchRequested);
  }

  final CreateTeam _createTeam;
  final JoinTeam _joinTeam;
  final GetMyTeams _getMyTeams;
  final SwitchActiveTeam _switchActiveTeam;

  Future<void> _reload(Emitter<TeamMembershipState> emit) async {
    final result = await _getMyTeams(const NoParams());
    result.fold(
      (failure) => emit(
        TeamMembershipFailure(failure.message, const TeamMembershipLoaded([])),
      ),
      (teams) => emit(TeamMembershipLoaded(teams)),
    );
  }

  Future<void> _onStarted(
    TeamMembershipStarted event,
    Emitter<TeamMembershipState> emit,
  ) async {
    emit(const TeamMembershipLoading());
    await _reload(emit);
  }

  Future<void> _onCreateRequested(
    TeamCreateRequested event,
    Emitter<TeamMembershipState> emit,
  ) async {
    final fallback = state;
    emit(TeamMembershipSubmitting(fallback));
    final result = await _createTeam(event.name);
    await result.fold(
      (failure) async => emit(TeamMembershipFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }

  Future<void> _onJoinRequested(
    TeamJoinRequested event,
    Emitter<TeamMembershipState> emit,
  ) async {
    final fallback = state;
    emit(TeamMembershipSubmitting(fallback));
    final result = await _joinTeam(event.inviteCode);
    await result.fold(
      (failure) async => emit(TeamMembershipFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }

  Future<void> _onSwitchRequested(
    TeamSwitchRequested event,
    Emitter<TeamMembershipState> emit,
  ) async {
    final fallback = state;
    emit(TeamMembershipSubmitting(fallback));
    final result = await _switchActiveTeam(event.teamId);
    await result.fold(
      (failure) async => emit(TeamMembershipFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }
}
