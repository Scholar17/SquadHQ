import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/player_rating.dart';
import '../../domain/usecases/player_rating_usecases.dart';

sealed class TeamRatingsEvent extends Equatable {
  const TeamRatingsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads [teamId]'s squad — again whenever the active team changes.
final class TeamRatingsStarted extends TeamRatingsEvent {
  const TeamRatingsStarted(this.teamId);

  final String teamId;

  @override
  List<Object?> get props => [teamId];
}

/// Reloads quietly (pull to refresh, after rating yourself).
final class TeamRatingsRefreshed extends TeamRatingsEvent {
  const TeamRatingsRefreshed();
}

/// The 10-match boost.
final class TeamRatingImproveRequested extends TeamRatingsEvent {
  const TeamRatingImproveRequested();
}

final class TeamRatingsState extends Equatable {
  const TeamRatingsState({
    this.teamId,
    this.players,
    this.improving = false,
    this.improvedTo,
    this.error,
  });

  final String? teamId;

  /// Null until the first load lands.
  final List<RatedPlayer>? players;
  final bool improving;

  /// The new OVR after a boost, for a snackbar.
  final int? improvedTo;
  final String? error;

  TeamRatingsState copyWith({
    String? teamId,
    List<RatedPlayer>? players,
    bool? improving,
    int? improvedTo,
    String? error,
  }) => TeamRatingsState(
    teamId: teamId ?? this.teamId,
    players: players ?? this.players,
    improving: improving ?? this.improving,
    improvedTo: improvedTo,
    error: error,
  );

  @override
  List<Object?> get props => [teamId, players, improving, improvedTo, error];
}

/// The Squad tab: the active team's players with their ratings.
class TeamRatingsBloc extends Bloc<TeamRatingsEvent, TeamRatingsState> {
  TeamRatingsBloc({required this._getTeamRatings, required this._improveRating})
    : super(const TeamRatingsState()) {
    on<TeamRatingsStarted>(_onStarted);
    on<TeamRatingsRefreshed>(_onRefreshed);
    on<TeamRatingImproveRequested>(_onImprove);
  }

  final GetTeamRatings _getTeamRatings;
  final ImproveRating _improveRating;

  Future<void> _onStarted(TeamRatingsStarted event, Emitter<TeamRatingsState> emit) async {
    // A different team: don't show the last one's squad while loading.
    if (event.teamId != state.teamId) emit(TeamRatingsState(teamId: event.teamId));
    await _load(emit);
  }

  Future<void> _onRefreshed(TeamRatingsRefreshed event, Emitter<TeamRatingsState> emit) =>
      _load(emit);

  Future<void> _load(Emitter<TeamRatingsState> emit) async {
    final teamId = state.teamId;
    if (teamId == null) return;
    final result = await _getTeamRatings(teamId);
    if (teamId != state.teamId) return;
    result.fold(
      (failure) => emit(state.copyWith(players: state.players ?? const [], error: failure.message)),
      (players) => emit(state.copyWith(players: players)),
    );
  }

  Future<void> _onImprove(TeamRatingImproveRequested event, Emitter<TeamRatingsState> emit) async {
    emit(state.copyWith(improving: true));
    final result = await _improveRating(const NoParams());
    await result.fold(
      (failure) async => emit(state.copyWith(improving: false, error: failure.message)),
      (rating) async {
        await _load(emit);
        emit(state.copyWith(improving: false, improvedTo: rating.ovr));
      },
    );
  }
}
