import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/comment.dart';
import '../entities/match_topic.dart';

abstract interface class MatchCommentsRepository {
  /// Every comment in [thread], oldest first, with its author's profile.
  Future<Either<Failure, List<Comment>>> getComments(MatchThread thread);

  /// A comment in [thread], or a reply to [parentId].
  Future<Either<Failure, Unit>> addComment(
    MatchThread thread, {
    required String body,
    String? parentId,
  });

  /// The author or a team admin; a top-level comment takes its replies.
  Future<Either<Failure, Unit>> deleteComment(String commentId);
}
