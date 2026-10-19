import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/match_questions.dart';
import '../repositories/match_repository.dart';

/// Game [gameNo] of [matchId] (null: the next one); null scores = Not sure.
typedef GameScore = ({String matchId, int? gameNo, int? ourScore, int? theirScore});

class SaveMatchGame implements UseCase<Unit, GameScore> {
  const SaveMatchGame(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(GameScore game) => _repository.saveMatchGame(
    matchId: game.matchId,
    gameNo: game.gameNo,
    ourScore: game.ourScore,
    theirScore: game.theirScore,
  );
}

class RemoveMatchGame implements UseCase<Unit, ({String matchId, int gameNo})> {
  const RemoveMatchGame(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(({String matchId, int gameNo}) game) =>
      _repository.removeMatchGame(matchId: game.matchId, gameNo: game.gameNo);
}

class SetMatchPlayed implements UseCase<Unit, ({String matchId, bool played})> {
  const SetMatchPlayed(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(({String matchId, bool played}) params) =>
      _repository.setMatchPlayed(matchId: params.matchId, played: params.played);
}

class SubmitMatchAnswers implements UseCase<Unit, ({String matchId, MatchAnswers answers})> {
  const SubmitMatchAnswers(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(({String matchId, MatchAnswers answers}) params) =>
      _repository.submitMatchAnswers(matchId: params.matchId, answers: params.answers);
}

class GetMyMatchAnswers implements UseCase<MatchAnswers?, String> {
  const GetMyMatchAnswers(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, MatchAnswers?>> call(String matchId) =>
      _repository.getMyMatchAnswers(matchId);
}
