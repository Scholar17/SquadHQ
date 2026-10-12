import 'package:dartz/dartz.dart';
import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/comments/domain/entities/comment.dart';
import 'package:squad_hq/features/comments/domain/entities/match_topic.dart';
import 'package:squad_hq/features/comments/domain/repositories/match_comments_repository.dart';

/// In-memory match and bill comments, keyed like match_comments.
class FakeMatchCommentsRepository implements MatchCommentsRepository {
  FakeMatchCommentsRepository({required this.userId});

  final String userId;
  final comments = <({MatchTopic topic, Comment comment})>[];
  var _nextId = 0;

  static const _names = {'test-1': 'Test Player', 'p-2': 'Aung Ko', 'p-3': 'Min Thu'};

  void reset() => comments.clear();

  List<Comment> inThread(MatchThread thread) => [
    for (final entry in comments)
      if (entry.topic == thread.topic && entry.comment.subjectId == thread.matchId) entry.comment,
  ];

  @override
  Future<Either<Failure, List<Comment>>> getComments(MatchThread thread) async =>
      Right(inThread(thread));

  @override
  Future<Either<Failure, Unit>> addComment(
    MatchThread thread, {
    required String body,
    String? parentId,
  }) async {
    commentAs(userId, thread, body, parentId: parentId);
    return const Right(unit);
  }

  /// [authorId] comments, as if on their own phone. Like add_match_comment,
  /// a reply to a reply joins the top thread.
  void commentAs(String authorId, MatchThread thread, String body, {String? parentId}) {
    final parent = parentId == null
        ? null
        : comments.firstWhere((entry) => entry.comment.id == parentId).comment;
    comments.add((
      topic: thread.topic,
      comment: Comment(
        id: 'match-comment-${_nextId++}',
        subjectId: thread.matchId,
        parentId: parent?.parentId ?? parent?.id,
        authorId: authorId,
        authorName: _names[authorId],
        body: body,
        createdAt: DateTime.now().add(Duration(milliseconds: _nextId)),
      ),
    ));
  }

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId) async {
    comments.removeWhere(
      (entry) => entry.comment.id == commentId || entry.comment.parentId == commentId,
    );
    return const Right(unit);
  }
}
