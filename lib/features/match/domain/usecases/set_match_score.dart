import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/match_repository.dart';

class SetMatchScoreParams extends Equatable {
  const SetMatchScoreParams({
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

class SetMatchScore implements UseCase<Unit, SetMatchScoreParams> {
  const SetMatchScore(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SetMatchScoreParams params) => _repository.setMatchScore(
        matchId: params.matchId,
        ourScore: params.ourScore,
        theirScore: params.theirScore,
      );
}
