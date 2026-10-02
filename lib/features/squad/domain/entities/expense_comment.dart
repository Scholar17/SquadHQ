import 'package:equatable/equatable.dart';

/// A comment on an expense. Threads are one level deep: a reply's
/// [parentId] is always a top-level comment.
class ExpenseComment extends Equatable {
  const ExpenseComment({
    required this.id,
    required this.expenseId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.parentId,
  });

  final String id;
  final String expenseId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final String? parentId;

  bool get isReply => parentId != null;

  @override
  List<Object?> get props => [id, expenseId, authorId, body, createdAt, parentId];
}

/// A top-level comment and its replies, oldest first.
typedef CommentThread = ({ExpenseComment comment, List<ExpenseComment> replies});

/// Groups [comments] (any order) into threads, oldest thread first.
List<CommentThread> threadsOf(List<ExpenseComment> comments) {
  final sorted = [...comments]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final replies = <String, List<ExpenseComment>>{};
  for (final comment in sorted.where((c) => c.isReply)) {
    replies.putIfAbsent(comment.parentId!, () => []).add(comment);
  }
  return [
    for (final comment in sorted.where((c) => !c.isReply))
      (comment: comment, replies: replies[comment.id] ?? const []),
  ];
}
