import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/match_repository.dart';
import '../datasources/match_remote_data_source.dart';

class MatchRepositoryImpl implements MatchRepository {
  const MatchRepositoryImpl(this._remoteDataSource);

  final MatchRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<Match>>> getUpcomingMatches(String teamId) async {
    try {
      return Right(await _remoteDataSource.getUpcomingMatches(teamId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Match>> createMatch({
    required String teamId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    double? feePerPlayer,
  }) async {
    try {
      return Right(await _remoteDataSource.createMatch(
        teamId: teamId,
        opponent: opponent,
        kickoffAt: kickoffAt,
        venue: venue,
        feePerPlayer: feePerPlayer,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
