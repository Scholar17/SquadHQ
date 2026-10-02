import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/team_changes.dart';
import '../../domain/usecases/create_match.dart';
import '../../domain/usecases/delete_match.dart';
import '../../domain/usecases/get_upcoming_matches.dart';
import '../../domain/usecases/nudge_match_rsvp.dart';
import '../../domain/usecases/update_match.dart';
import 'match_event.dart';
import 'match_state.dart';

/// Singleton, provided at the app root (see app.dart) — like
/// TeamMembershipBloc, it needs to be reachable from Home and from the
/// create-match sheet, which sits outside AppShellPage's local providers.
class MatchBloc extends Bloc<MatchEvent, MatchState> {
  MatchBloc({
    required GetUpcomingMatches getUpcomingMatches,
    required CreateMatch createMatch,
    required UpdateMatch updateMatch,
    required DeleteMatch deleteMatch,
    required NudgeMatchRsvp nudgeMatchRsvp,
    required TeamChanges teamChanges,
  })  : _nudgeMatchRsvp = nudgeMatchRsvp,
        _getUpcomingMatches = getUpcomingMatches,
        _createMatch = createMatch,
        _updateMatch = updateMatch,
        _deleteMatch = deleteMatch,
        super(const MatchLoading()) {
    _serverChanges = TeamChangeWatcher(
      teamChanges,
      tables: const {TeamTable.matches},
      onChange: () {
        if (!isClosed) add(const MatchRefreshRequested());
      },
    );
    on<MatchTeamSelected>(_onTeamSelected);
    on<MatchRefreshRequested>((event, emit) => _reload(emit));
    on<MatchCreateRequested>(_onCreateRequested);
    on<MatchUpdateRequested>(_onUpdateRequested);
    on<MatchDeleteRequested>(_onDeleteRequested);
    on<MatchNudgeRequested>(_onNudgeRequested);
  }

  final GetUpcomingMatches _getUpcomingMatches;
  final CreateMatch _createMatch;
  final UpdateMatch _updateMatch;
  final DeleteMatch _deleteMatch;
  final NudgeMatchRsvp _nudgeMatchRsvp;

  /// Reloads when a match is created, edited, cancelled or nudged.
  late final TeamChangeWatcher _serverChanges;

  String? _teamId;

  @override
  Future<void> close() async {
    await _serverChanges.cancel();
    return super.close();
  }

  Future<void> _reload(Emitter<MatchState> emit) async {
    final teamId = _teamId;
    if (teamId == null) {
      emit(const MatchLoaded([]));
      return;
    }
    final result = await _getUpcomingMatches(teamId);
    result.fold(
      (failure) => emit(MatchFailure(failure.message, const MatchLoaded([]))),
      (matches) => emit(MatchLoaded(matches)),
    );
  }

  Future<void> _onTeamSelected(
    MatchTeamSelected event,
    Emitter<MatchState> emit,
  ) async {
    _serverChanges.watch(event.teamId);
    _teamId = event.teamId;
    emit(const MatchLoading());
    await _reload(emit);
  }

  Future<void> _onCreateRequested(
    MatchCreateRequested event,
    Emitter<MatchState> emit,
  ) async {
    final fallback = state;
    emit(MatchSubmitting(fallback));
    final result = await _createMatch(
      CreateMatchParams(
        teamId: event.teamId,
        opponent: event.opponent,
        kickoffAt: event.kickoffAt,
        venue: event.venue,
        durationMinutes: event.durationMinutes,
        playersNeeded: event.playersNeeded,
      ),
    );
    await result.fold(
      (failure) async => emit(MatchFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }

  Future<void> _onUpdateRequested(
    MatchUpdateRequested event,
    Emitter<MatchState> emit,
  ) async {
    final fallback = state;
    emit(MatchSubmitting(fallback));
    final result = await _updateMatch(
      UpdateMatchParams(
        matchId: event.matchId,
        opponent: event.opponent,
        kickoffAt: event.kickoffAt,
        venue: event.venue,
        durationMinutes: event.durationMinutes,
        playersNeeded: event.playersNeeded,
      ),
    );
    await result.fold(
      (failure) async => emit(MatchFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }

  Future<void> _onDeleteRequested(
    MatchDeleteRequested event,
    Emitter<MatchState> emit,
  ) async {
    final fallback = state;
    emit(MatchSubmitting(fallback));
    final result = await _deleteMatch(event.matchId);
    await result.fold(
      (failure) async => emit(MatchFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }

  Future<void> _onNudgeRequested(
    MatchNudgeRequested event,
    Emitter<MatchState> emit,
  ) async {
    final fallback = state;
    emit(MatchSubmitting(fallback));
    final result = await _nudgeMatchRsvp(event.matchId);
    await result.fold(
      (failure) async => emit(MatchFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }
}
