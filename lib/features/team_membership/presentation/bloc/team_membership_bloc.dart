import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/realtime/team_changes.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/create_team.dart';
import '../../domain/usecases/get_my_teams.dart';
import '../../domain/usecases/join_team.dart';
import '../../domain/usecases/leave_team.dart';
import '../../domain/usecases/remove_team_member.dart';
import '../../domain/usecases/set_team_timezone.dart';
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
    required SetTeamTimezone setTeamTimezone,
    required LeaveTeam leaveTeam,
    required RemoveTeamMember removeTeamMember,
    required TeamChanges teamChanges,
  })  : _setTeamTimezone = setTeamTimezone,
        _leaveTeam = leaveTeam,
        _removeTeamMember = removeTeamMember,
        _createTeam = createTeam,
        _joinTeam = joinTeam,
        _getMyTeams = getMyTeams,
        _switchActiveTeam = switchActiveTeam,
        super(const TeamMembershipLoading()) {
    // Your own role or membership changed elsewhere (made admin, removed
    // from the group): reload, so the app moves on from a group you've
    // left.
    _serverChanges = TeamChangeWatcher(
      teamChanges,
      tables: const {TeamTable.teamMembers},
      onChange: () {
        if (!isClosed) add(const TeamMembershipRefreshRequested());
      },
    );
    on<TeamMembershipStarted>(_onStarted);
    on<TeamMembershipRefreshRequested>((event, emit) => _reload(emit));
    on<TeamLeaveRequested>(
      (event, emit) => _submitQuietly(
        emit,
        () => _leaveTeam(LeaveTeamParams(teamId: event.teamId, newOwnerId: event.newOwnerId)),
        event.done,
      ),
    );
    on<TeamMemberRemoveRequested>(
      (event, emit) => _submitQuietly(
        emit,
        () => _removeTeamMember(
          RemoveTeamMemberParams(teamId: event.teamId, profileId: event.profileId),
        ),
        event.done,
      ),
    );
    on<TeamCreateRequested>(_onCreateRequested);
    on<TeamJoinRequested>(_onJoinRequested);
    on<TeamSwitchRequested>(_onSwitchRequested);
    on<TeamTimezoneChangeRequested>(_onTimezoneChangeRequested);
  }

  final CreateTeam _createTeam;
  final JoinTeam _joinTeam;
  final GetMyTeams _getMyTeams;
  final SwitchActiveTeam _switchActiveTeam;
  final SetTeamTimezone _setTeamTimezone;
  final LeaveTeam _leaveTeam;
  final RemoveTeamMember _removeTeamMember;
  late final TeamChangeWatcher _serverChanges;

  Future<void> _reload(Emitter<TeamMembershipState> emit) async {
    final result = await _getMyTeams(const NoParams());
    result.fold(
      (failure) => emit(
        TeamMembershipFailure(failure.message, const TeamMembershipLoaded([])),
      ),
      (teams) {
        emit(TeamMembershipLoaded(teams));
        _serverChanges.watch(teams.where((team) => team.isActive).firstOrNull?.id);
      },
    );
  }

  /// Leave/remove: a failure goes back through [done] (the caller shows
  /// it) rather than as a [TeamMembershipFailure], which only the groups
  /// page shows.
  Future<void> _submitQuietly(
    Emitter<TeamMembershipState> emit,
    Future<Either<Failure, Unit>> Function() submit,
    void Function(String? error)? done,
  ) async {
    // The settled state, so an older failure isn't shown again.
    final fallback = switch (state) {
      TeamMembershipSubmitting(:final previous) || TeamMembershipFailure(:final previous) =>
        previous,
      final settled => settled,
    };
    emit(TeamMembershipSubmitting(fallback));
    final result = await submit();
    await result.fold(
      (failure) async {
        emit(fallback);
        done?.call(failure.message);
      },
      (_) async {
        await _reload(emit);
        done?.call(null);
      },
    );
  }

  @override
  Future<void> close() async {
    await _serverChanges.cancel();
    return super.close();
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
    final result = await _createTeam(
      CreateTeamParams(name: event.name, kind: event.kind, currency: event.currency),
    );
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

  Future<void> _onTimezoneChangeRequested(
    TeamTimezoneChangeRequested event,
    Emitter<TeamMembershipState> emit,
  ) async {
    final fallback = state;
    emit(TeamMembershipSubmitting(fallback));
    final result = await _setTeamTimezone(
      SetTeamTimezoneParams(teamId: event.teamId, timezone: event.timezone),
    );
    await result.fold(
      (failure) async => emit(TeamMembershipFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }
}
