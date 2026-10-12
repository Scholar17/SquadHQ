import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/match_topic.dart';
import '../../domain/repositories/match_comments_repository.dart';
import '../datasources/match_comments_remote_data_source.dart';

class MatchCommentsRepositoryImpl implements MatchCommentsRepository {
  const MatchCommentsRepositoryImpl(this._remoteDataSource);

  final MatchCommentsRemoteDataSource _remoteDataSource;

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
  Future<Either<Failure, List<Comment>>> getComments(MatchThread thread) =>
      _guard(() => _remoteDataSource.getComments(thread));

  @override
  Future<Either<Failure, Unit>> addComment(
    MatchThread thread, {
    required String body,
    String? parentId,
  }) => _guard(() async {
    await _remoteDataSource.addComment(thread, body: body, parentId: parentId);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId) => _guard(() async {
    await _remoteDataSource.deleteComment(commentId);
    return unit;
  });
}
