import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/team_changes.dart';

import '../../domain/entities/match_history.dart';
import '../../domain/usecases/get_match_history.dart';
import '../../domain/usecases/set_match_score.dart';
import '../../domain/usecases/vote_motm.dart';

sealed class MatchHistoryEvent extends Equatable {
  const MatchHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Fired whenever the active team changes (including to/from no team).
final class MatchHistoryTeamSelected extends MatchHistoryEvent {
  const MatchHistoryTeamSelected(this.teamId);

  final String? teamId;

  @override
  List<Object?> get props => [teamId];
}

/// Reloads the history — with a spinner the first time, quietly after that
/// (pull-to-refresh, opening the history page, the periodic refresh). [done] completes when the load finishes, since an
/// unchanged history emits no new state to wait on.
final class MatchHistoryStarted extends MatchHistoryEvent {
  const MatchHistoryStarted({this.done});

  final Completer<void>? done;

  @override
  List<Object?> get props => [done];
}

final class MatchScoreSubmitted extends MatchHistoryEvent {
  const MatchScoreSubmitted({
    required this.matchId,
    required this.ourScore,
    required this.theirScore,
  });

  final String matchId;
  final int ourScore;
  final int theirScore;

  @override
  List<Object?> get props => [matchId, ourScore, theirScore];
}

final class MotmVoteSubmitted extends MatchHistoryEvent {
  const MotmVoteSubmitted({required this.matchId, required this.nomineeId});

  final String matchId;
  final String nomineeId;

  @override
  List<Object?> get props => [matchId, nomineeId];
}

sealed class MatchHistoryState extends Equatable {
  const MatchHistoryState();

  @override
  List<Object?> get props => [];
}

final class MatchHistoryLoading extends MatchHistoryState {
  const MatchHistoryLoading();
}

final class MatchHistoryLoaded extends MatchHistoryState {
  const MatchHistoryLoaded(this.history);

  final MatchHistory history;

  @override
  List<Object?> get props => [history];
}

/// A score or vote is in flight; [previous] is what to fall back to
/// (always [MatchHistoryLoaded] in practice).
final class MatchHistorySubmitting extends MatchHistoryState {
  const MatchHistorySubmitting(this.previous);

  final MatchHistoryState previous;

  @override
  List<Object?> get props => [previous];
}

final class MatchHistoryFailure extends MatchHistoryState {
  const MatchHistoryFailure(this.message, this.previous);

  final String message;
  final MatchHistoryState previous;

  @override
  List<Object?> get props => [message, previous];
}

extension MatchHistoryStateX on MatchHistoryState {
  /// Unwraps Submitting/Failure — those never nest (see MatchHistoryBloc).
  MatchHistory? get history => switch (this) {
        MatchHistoryLoaded(:final history) => history,
        MatchHistorySubmitting(:final previous) ||
        MatchHistoryFailure(:final previous) =>
          previous.history,
        MatchHistoryLoading() => null,
      };
}

/// Singleton, provided at the app root (see app.dart) like MatchBloc — the
/// active team's past matches, scores and Man of the Match votes. Home's
/// recaps, the tab badges and the history pages all read it, so a vote or
/// score shows everywhere at once.
class MatchHistoryBloc extends Bloc<MatchHistoryEvent, MatchHistoryState> {
  MatchHistoryBloc({
    required GetMatchHistory getMatchHistory,
    required SetMatchScore setMatchScore,
    required VoteMotm voteMotm,
    required TeamChanges teamChanges,
  })  : _getMatchHistory = getMatchHistory,
        _setMatchScore = setMatchScore,
        _voteMotm = voteMotm,
        super(const MatchHistoryLoading()) {
    _serverChanges = TeamChangeWatcher(
      teamChanges,
      tables: const {
        TeamTable.teams,
        TeamTable.teamMembers,
        TeamTable.matches,
        TeamTable.matchRsvps,
        TeamTable.motmVotes,
      },
      onChange: () {
        if (!isClosed) add(const MatchHistoryStarted());
      },
    );
    on<MatchHistoryTeamSelected>(_onTeamSelected);
    on<MatchHistoryStarted>(_onStarted);
    on<MatchScoreSubmitted>(_onScoreSubmitted);
    on<MotmVoteSubmitted>(_onMotmVoteSubmitted);
  }

  String? _teamId;
  final GetMatchHistory _getMatchHistory;
  final SetMatchScore _setMatchScore;
  final VoteMotm _voteMotm;

  /// Reloads when a score, MOTM vote, RSVP or the squad changes.
  late final TeamChangeWatcher _serverChanges;

  @override
  Future<void> close() async {
    await _serverChanges.cancel();
    return super.close();
  }

  Future<void> _reload(Emitter<MatchHistoryState> emit) async {
    final teamId = _teamId;
    if (teamId == null) {
      emit(const MatchHistoryLoaded(MatchHistory()));
      return;
    }
    final result = await _getMatchHistory(teamId);
    result.fold(
      (failure) => emit(
        MatchHistoryFailure(failure.message, const MatchHistoryLoaded(MatchHistory())),
      ),
      (history) => emit(MatchHistoryLoaded(history)),
    );
  }

  MatchHistoryState get _fallback => switch (state) {
        MatchHistorySubmitting(:final previous) ||
        MatchHistoryFailure(:final previous) =>
          previous,
        final settled => settled,
      };

  Future<void> _onTeamSelected(
    MatchHistoryTeamSelected event,
    Emitter<MatchHistoryState> emit,
  ) async {
    _serverChanges.watch(event.teamId);
    _teamId = event.teamId;
    emit(const MatchHistoryLoading());
    await _reload(emit);
  }

  Future<void> _onStarted(
    MatchHistoryStarted event,
    Emitter<MatchHistoryState> emit,
  ) async {
    try {
      if (state.history == null) emit(const MatchHistoryLoading());
      await _reload(emit);
    } finally {
      event.done?.complete();
    }
  }

  Future<void> _onScoreSubmitted(
    MatchScoreSubmitted event,
    Emitter<MatchHistoryState> emit,
  ) async {
    final fallback = _fallback;
    emit(MatchHistorySubmitting(fallback));
    final result = await _setMatchScore(
      SetMatchScoreParams(
        matchId: event.matchId,
        ourScore: event.ourScore,
        theirScore: event.theirScore,
      ),
    );
    await result.fold(
      (failure) async => emit(MatchHistoryFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }

  Future<void> _onMotmVoteSubmitted(
    MotmVoteSubmitted event,
    Emitter<MatchHistoryState> emit,
  ) async {
    final fallback = _fallback;
    emit(MatchHistorySubmitting(fallback));
    final result = await _voteMotm(
      VoteMotmParams(matchId: event.matchId, nomineeId: event.nomineeId),
    );
    await result.fold(
      (failure) async => emit(MatchHistoryFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }
}
