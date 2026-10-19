import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/repositories/invite_repository.dart';
import '../datasources/invite_remote_data_source.dart';

class InviteRepositoryImpl implements InviteRepository {
  const InviteRepositoryImpl(this._remoteDataSource);

  final InviteRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<InviteCandidate>>> searchCandidates(String teamId, String query) =>
      _guard(() => _remoteDataSource.searchCandidates(teamId, query));

  @override
  Future<Either<Failure, Unit>> invite(String teamId, String profileId) => _guard(() async {
    await _remoteDataSource.invite(teamId, profileId);
    return unit;
  });

  @override
  Future<Either<Failure, List<GroupInvite>>> myInvites() =>
      _guard(_remoteDataSource.myInvites);

  @override
  Future<Either<Failure, Unit>> respond(String inviteId, {required bool accept}) =>
      _guard(() async {
        await _remoteDataSource.respond(inviteId, accept: accept);
        return unit;
      });

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
