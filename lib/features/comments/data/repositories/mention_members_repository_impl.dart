import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/mention.dart';
import '../../domain/repositories/mention_members_repository.dart';
import '../datasources/mention_members_remote_data_source.dart';

class MentionMembersRepositoryImpl implements MentionMembersRepository {
  const MentionMembersRepositoryImpl(this._remoteDataSource);

  final MentionMembersRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<MentionMember>>> getMembers(String teamId) async {
    try {
      return Right(await _remoteDataSource.getMembers(teamId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }
}
