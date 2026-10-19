import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_history.dart';
import '../../domain/entities/match_questions.dart';
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
    String? venueId,
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    try {
      return Right(await _remoteDataSource.createMatch(
        teamId: teamId,
        opponent: opponent,
        kickoffAt: kickoffAt,
        venue: venue,
        venueId: venueId,
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
    String? venueId,
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    try {
      return Right(await _remoteDataSource.updateMatch(
        matchId: matchId,
        opponent: opponent,
        kickoffAt: kickoffAt,
        venue: venue,
        venueId: venueId,
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
  Future<Either<Failure, Unit>> saveMatchGame({
    required String matchId,
    int? gameNo,
    int? ourScore,
    int? theirScore,
  }) => _guard(() async {
    await _remoteDataSource.saveMatchGame(
      matchId: matchId,
      gameNo: gameNo,
      ourScore: ourScore,
      theirScore: theirScore,
    );
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> removeMatchGame({required String matchId, required int gameNo}) =>
      _guard(() async {
        await _remoteDataSource.removeMatchGame(matchId: matchId, gameNo: gameNo);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> setMatchPlayed({required String matchId, required bool played}) =>
      _guard(() async {
        await _remoteDataSource.setMatchPlayed(matchId: matchId, played: played);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> submitMatchAnswers({
    required String matchId,
    required MatchAnswers answers,
  }) => _guard(() async {
    await _remoteDataSource.submitMatchAnswers(matchId: matchId, answers: answers);
    return unit;
  });

  @override
  Future<Either<Failure, MatchAnswers?>> getMyMatchAnswers(String matchId) =>
      _guard(() => _remoteDataSource.getMyMatchAnswers(matchId));

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
