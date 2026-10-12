import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/comment.dart';
import '../entities/match_topic.dart';
import '../repositories/match_comments_repository.dart';

class GetMatchComments implements UseCase<List<Comment>, MatchThread> {
  const GetMatchComments(this._repository);

  final MatchCommentsRepository _repository;

  @override
  Future<Either<Failure, List<Comment>>> call(MatchThread thread) =>
      _repository.getComments(thread);
}

typedef NewMatchComment = ({MatchThread thread, String body, String? parentId});

class AddMatchComment implements UseCase<Unit, NewMatchComment> {
  const AddMatchComment(this._repository);

  final MatchCommentsRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NewMatchComment comment) =>
      _repository.addComment(comment.thread, body: comment.body, parentId: comment.parentId);
}

class DeleteMatchComment implements UseCase<Unit, String> {
  const DeleteMatchComment(this._repository);

  final MatchCommentsRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String commentId) => _repository.deleteComment(commentId);
}
