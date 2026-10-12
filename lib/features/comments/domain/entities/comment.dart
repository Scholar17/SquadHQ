import 'package:equatable/equatable.dart';

/// A comment on something — a squad expense, a football match or a match's
/// bill ([subjectId]). Threads are one level deep: a reply's [parentId] is
/// always a top-level comment.
class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.subjectId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.authorName,
    this.authorPhotoUrl,
  });

  final String id;
  final String subjectId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final String? parentId;

  /// The author's profile, where the screen has no member list to look it
  /// up in (match and bill comments).
  final String? authorName;
  final String? authorPhotoUrl;

  bool get isReply => parentId != null;

  @override
  List<Object?> get props => [
    id,
    subjectId,
    authorId,
    body,
    createdAt,
    parentId,
    authorName,
    authorPhotoUrl,
  ];
}

/// A top-level comment and its replies, oldest first.
typedef CommentThread = ({Comment comment, List<Comment> replies});

/// Groups [comments] (any order) into threads, oldest thread first.
List<CommentThread> threadsOf(List<Comment> comments) {
  final sorted = [...comments]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final replies = <String, List<Comment>>{};
  for (final comment in sorted.where((c) => c.isReply)) {
    replies.putIfAbsent(comment.parentId!, () => []).add(comment);
  }
  return [
    for (final comment in sorted.where((c) => !c.isReply))
      (comment: comment, replies: replies[comment.id] ?? const []),
  ];
}
