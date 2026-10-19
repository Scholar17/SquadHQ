import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/share_link.dart';
import '../../domain/repositories/share_repository.dart';
import '../datasources/share_remote_data_source.dart';

class ShareRepositoryImpl implements ShareRepository {
  const ShareRepositoryImpl(this._remoteDataSource);

  final ShareRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, String>> getShareLink(String matchId, ShareKind kind) =>
      _guard(() => _remoteDataSource.getShareLink(matchId, kind));

  @override
  Future<Either<Failure, Unit>> recordShare(String matchId, ShareKind kind) =>
      _guard(() async {
        await _remoteDataSource.recordShare(matchId, kind);
        return unit;
      });

  @override
  Future<Either<Failure, OpenedShare?>> openShareLink(String token) =>
      _guard(() => _remoteDataSource.openShareLink(token));

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }
}
