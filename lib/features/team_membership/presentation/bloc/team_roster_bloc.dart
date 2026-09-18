import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/team.dart';
import '../../domain/usecases/delete_team.dart';
import '../../domain/usecases/get_team_members.dart';
import '../../domain/usecases/set_member_role.dart';
import 'team_roster_event.dart';
import 'team_roster_state.dart';

/// Page-scoped (one per [TeamRosterPage] visit) — unlike the app-wide
/// [TeamMembershipBloc], a team's roster is only ever needed while that
/// page is open.
class TeamRosterBloc extends Bloc<TeamRosterEvent, TeamRosterState> {
  TeamRosterBloc({
    required this.teamId,
    required GetTeamMembers getTeamMembers,
    required SetMemberRole setMemberRole,
    required DeleteTeam deleteTeam,
  })  : _getTeamMembers = getTeamMembers,
        _setMemberRole = setMemberRole,
        _deleteTeam = deleteTeam,
        super(const TeamRosterLoading()) {
    on<TeamRosterStarted>(_onStarted);
    on<TeamRosterPromoteRequested>(_onPromoteRequested);
    on<TeamRosterDemoteRequested>(_onDemoteRequested);
    on<TeamRosterDeleteTeamRequested>(_onDeleteTeamRequested);
  }

  final String teamId;
  final GetTeamMembers _getTeamMembers;
  final SetMemberRole _setMemberRole;
  final DeleteTeam _deleteTeam;

  Future<void> _reload(Emitter<TeamRosterState> emit) async {
    final result = await _getTeamMembers(teamId);
    result.fold(
      (failure) =>
          emit(TeamRosterFailure(failure.message, const TeamRosterLoaded([]))),
      (members) => emit(TeamRosterLoaded(members)),
    );
  }

  Future<void> _onStarted(
    TeamRosterStarted event,
    Emitter<TeamRosterState> emit,
  ) async {
    emit(const TeamRosterLoading());
    await _reload(emit);
  }

  Future<void> _setRole(
    String profileId,
    TeamRole role,
    Emitter<TeamRosterState> emit,
  ) async {
    final fallback = state;
    emit(TeamRosterSubmitting(fallback));
    final result = await _setMemberRole(
      SetMemberRoleParams(teamId: teamId, profileId: profileId, role: role),
    );
    await result.fold(
      (failure) async => emit(TeamRosterFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }

  Future<void> _onPromoteRequested(
    TeamRosterPromoteRequested event,
    Emitter<TeamRosterState> emit,
  ) =>
      _setRole(event.profileId, TeamRole.admin, emit);

  Future<void> _onDemoteRequested(
    TeamRosterDemoteRequested event,
    Emitter<TeamRosterState> emit,
  ) =>
      _setRole(event.profileId, TeamRole.player, emit);

  Future<void> _onDeleteTeamRequested(
    TeamRosterDeleteTeamRequested event,
    Emitter<TeamRosterState> emit,
  ) async {
    final fallback = state;
    emit(TeamRosterSubmitting(fallback));
    final result = await _deleteTeam(teamId);
    result.fold(
      (failure) => emit(TeamRosterFailure(failure.message, fallback)),
      (_) => emit(const TeamRosterTeamDeleted()),
    );
  }
}
