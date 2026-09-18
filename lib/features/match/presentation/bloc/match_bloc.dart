import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_match.dart';
import '../../domain/usecases/get_upcoming_matches.dart';
import 'match_event.dart';
import 'match_state.dart';

/// Singleton, provided at the app root (see app.dart) — like
/// TeamMembershipBloc, it needs to be reachable from Home and from the
/// create-match sheet, which sits outside AppShellPage's local providers.
class MatchBloc extends Bloc<MatchEvent, MatchState> {
  MatchBloc({
    required GetUpcomingMatches getUpcomingMatches,
    required CreateMatch createMatch,
  })  : _getUpcomingMatches = getUpcomingMatches,
        _createMatch = createMatch,
        super(const MatchLoading()) {
    on<MatchTeamSelected>(_onTeamSelected);
    on<MatchCreateRequested>(_onCreateRequested);
  }

  final GetUpcomingMatches _getUpcomingMatches;
  final CreateMatch _createMatch;

  String? _teamId;

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
        feePerPlayer: event.feePerPlayer,
      ),
    );
    await result.fold(
      (failure) async => emit(MatchFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }
}
