import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/match.dart';
import '../repositories/match_repository.dart';

class UpdateMatchParams extends Equatable {
  const UpdateMatchParams({
    required this.matchId,
    required this.opponent,
    required this.kickoffAt,
    this.venue,
    required this.durationMinutes,
    this.playersNeeded,
  });

  final String matchId;
  final String opponent;
  final DateTime kickoffAt;
  final String? venue;
  final int durationMinutes;
  final int? playersNeeded;

  @override
  List<Object?> get props => [matchId, opponent, kickoffAt, venue, durationMinutes, playersNeeded];
}

class UpdateMatch implements UseCase<Match, UpdateMatchParams> {
  const UpdateMatch(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Match>> call(UpdateMatchParams params) =>
      _repository.updateMatch(
        matchId: params.matchId,
        opponent: params.opponent,
        kickoffAt: params.kickoffAt,
        venue: params.venue,
        durationMinutes: params.durationMinutes,
        playersNeeded: params.playersNeeded,
      );
}
