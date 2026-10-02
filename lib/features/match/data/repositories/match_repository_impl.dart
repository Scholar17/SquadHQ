import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_history.dart';
import '../../domain/entities/matchday_player.dart';
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
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, Match>> createMatch({
    required String teamId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    try {
      return Right(await _remoteDataSource.createMatch(
        teamId: teamId,
        opponent: opponent,
        kickoffAt: kickoffAt,
        venue: venue,
        durationMinutes: durationMinutes,
        playersNeeded: playersNeeded,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, Match>> updateMatch({
    required String matchId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    try {
      return Right(await _remoteDataSource.updateMatch(
        matchId: matchId,
        opponent: opponent,
        kickoffAt: kickoffAt,
        venue: venue,
        durationMinutes: durationMinutes,
        playersNeeded: playersNeeded,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteMatch(String matchId) async {
    try {
      await _remoteDataSource.deleteMatch(matchId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, List<MatchdayPlayer>>> getMatchdayRoster({
    required String teamId,
    required String matchId,
  }) async {
    try {
      return Right(await _remoteDataSource.getMatchdayRoster(
        teamId: teamId,
        matchId: matchId,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, Unit>> setRsvp({
    required String matchId,
    required RsvpAnswer answer,
  }) async {
    try {
      await _remoteDataSource.setRsvp(matchId: matchId, answer: answer);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, MatchHistory>> getMatchHistory(String teamId) async {
    try {
      return Right(await _remoteDataSource.getMatchHistory(teamId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, Unit>> setMatchScore({
    required String matchId,
    required int ourScore,
    required int theirScore,
  }) async {
    try {
      await _remoteDataSource.setMatchScore(
        matchId: matchId,
        ourScore: ourScore,
        theirScore: theirScore,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, Unit>> voteMotm({
    required String matchId,
    required String nomineeId,
  }) async {
    try {
      await _remoteDataSource.voteMotm(matchId: matchId, nomineeId: nomineeId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, Unit>> nudgeMatchRsvp(String matchId) async {
    try {
      await _remoteDataSource.nudgeMatchRsvp(matchId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }
}
