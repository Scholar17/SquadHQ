import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/team_changes.dart';
import '../../domain/entities/match.dart';
import '../../domain/usecases/get_matchday_roster.dart';
import '../../domain/usecases/set_match_rsvp.dart';
import 'matchday_event.dart';
import 'matchday_state.dart';

/// One instance per match shown on the Match tab (see MatchPage) — the
/// squad list and RSVPs for [match].
class MatchdayBloc extends Bloc<MatchdayEvent, MatchdayState> {
  MatchdayBloc({
    required this.match,
    required GetMatchdayRoster getMatchdayRoster,
    required SetMatchRsvp setMatchRsvp,
    required TeamChanges teamChanges,
  })  : _getMatchdayRoster = getMatchdayRoster,
        _setMatchRsvp = setMatchRsvp,
        super(const MatchdayLoading()) {
    _serverChanges = TeamChangeWatcher(
      teamChanges,
      tables: const {TeamTable.teamMembers, TeamTable.matchRsvps},
      onChange: () {
        if (!isClosed) add(const MatchdayRefreshRequested());
      },
    )..watch(match.teamId);
    on<MatchdayStarted>(_onStarted);
    on<MatchdayRefreshRequested>((event, emit) => _reload(emit));
    on<MatchdayRsvpSubmitted>(_onRsvpSubmitted);
  }

  final Match match;
  final GetMatchdayRoster _getMatchdayRoster;
  final SetMatchRsvp _setMatchRsvp;

  /// Reloads when a teammate RSVPs or the squad changes.
  late final TeamChangeWatcher _serverChanges;

  @override
  Future<void> close() async {
    await _serverChanges.cancel();
    return super.close();
  }

  Future<void> _reload(Emitter<MatchdayState> emit) async {
    final result = await _getMatchdayRoster(
      GetMatchdayRosterParams(teamId: match.teamId, matchId: match.id),
    );
    result.fold(
      (failure) => emit(MatchdayFailure(failure.message, const MatchdayLoaded([]))),
      (players) => emit(MatchdayLoaded(players)),
    );
  }

  Future<void> _onStarted(MatchdayStarted event, Emitter<MatchdayState> emit) async {
    emit(const MatchdayLoading());
    await _reload(emit);
  }

  Future<void> _onRsvpSubmitted(
    MatchdayRsvpSubmitted event,
    Emitter<MatchdayState> emit,
  ) async {
    // Unwrap a previous failure so Submitting/Failure never nest.
    final fallback = switch (state) {
      MatchdayFailure(:final previous) => previous,
      final settled => settled,
    };
    emit(MatchdaySubmitting(fallback));
    final result = await _setMatchRsvp(
      SetMatchRsvpParams(matchId: match.id, answer: event.answer),
    );
    await result.fold(
      (failure) async => emit(MatchdayFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }
}
