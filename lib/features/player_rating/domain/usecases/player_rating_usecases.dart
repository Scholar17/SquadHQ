import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/player_rating.dart';
import '../repositories/player_rating_repository.dart';

class GetTeamRatings implements UseCase<List<RatedPlayer>, String> {
  const GetTeamRatings(this._repository);

  final PlayerRatingRepository _repository;

  @override
  Future<Either<Failure, List<RatedPlayer>>> call(String teamId) =>
      _repository.getTeamRatings(teamId);
}

class GetMyRating implements UseCase<PlayerRating?, NoParams> {
  const GetMyRating(this._repository);

  final PlayerRatingRepository _repository;

  @override
  Future<Either<Failure, PlayerRating?>> call(NoParams params) => _repository.getMyRating();
}

class GetRatingPositions implements UseCase<List<RatingPosition>, NoParams> {
  const GetRatingPositions(this._repository);

  final PlayerRatingRepository _repository;

  @override
  Future<Either<Failure, List<RatingPosition>>> call(NoParams params) => _repository.getPositions();
}

class GetRatingQuestions implements UseCase<List<RatingQuestion>, String> {
  const GetRatingQuestions(this._repository);

  final PlayerRatingRepository _repository;

  @override
  Future<Either<Failure, List<RatingQuestion>>> call(String mainPosition) =>
      _repository.getQuestions(mainPosition);
}

typedef RatingAnswers = ({List<String> positions, List<String> answerIds});

class SubmitRating implements UseCase<PlayerRating, RatingAnswers> {
  const SubmitRating(this._repository);

  final PlayerRatingRepository _repository;

  @override
  Future<Either<Failure, PlayerRating>> call(RatingAnswers answers) =>
      _repository.submitRating(positions: answers.positions, answerIds: answers.answerIds);
}

class ImproveRating implements UseCase<PlayerRating, NoParams> {
  const ImproveRating(this._repository);

  final PlayerRatingRepository _repository;

  @override
  Future<Either<Failure, PlayerRating>> call(NoParams params) => _repository.improveRating();
}

class GetMyMatchStats implements UseCase<MatchStats, String> {
  const GetMyMatchStats(this._repository);

  final PlayerRatingRepository _repository;

  @override
  Future<Either<Failure, MatchStats>> call(String matchId) => _repository.getMyMatchStats(matchId);
}

typedef LoggedStats = ({String matchId, MatchStats stats});

class LogMatchStats implements UseCase<Unit, LoggedStats> {
  const LogMatchStats(this._repository);

  final PlayerRatingRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(LoggedStats logged) =>
      _repository.logMatchStats(logged.matchId, logged.stats);
}
