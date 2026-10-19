import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/player_rating.dart';
import '../../domain/repositories/player_rating_repository.dart';
import '../datasources/player_rating_remote_data_source.dart';

class PlayerRatingRepositoryImpl implements PlayerRatingRepository {
  const PlayerRatingRepositoryImpl(this._remoteDataSource);

  final PlayerRatingRemoteDataSource _remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, List<RatedPlayer>>> getTeamRatings(String teamId) =>
      _guard(() => _remoteDataSource.getTeamRatings(teamId));

  @override
  Future<Either<Failure, PlayerRating?>> getMyRating() => _guard(_remoteDataSource.getMyRating);

  @override
  Future<Either<Failure, List<RatingPosition>>> getPositions() =>
      _guard(_remoteDataSource.getPositions);

  @override
  Future<Either<Failure, List<RatingQuestion>>> getQuestions(String mainPosition) =>
      _guard(() => _remoteDataSource.getQuestions(mainPosition));

  @override
  Future<Either<Failure, PlayerRating>> submitRating({
    required List<String> positions,
    required List<String> answerIds,
  }) => _guard(() => _remoteDataSource.submitRating(positions: positions, answerIds: answerIds));

  @override
  Future<Either<Failure, PlayerRating>> improveRating() => _guard(_remoteDataSource.improveRating);
}
