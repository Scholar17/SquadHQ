import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/match_topic.dart';

abstract interface class MatchCommentsRemoteDataSource {
  Future<List<Comment>> getComments(MatchThread thread);

  Future<void> addComment(MatchThread thread, {required String body, String? parentId});

  Future<void> deleteComment(String commentId);
}

/// supabase/sql/043_match_comments.sql.
class MatchCommentsRemoteDataSourceImpl implements MatchCommentsRemoteDataSource {
  MatchCommentsRemoteDataSourceImpl({required SupabaseClient supabaseClient})
    : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<Comment>> getComments(MatchThread thread) => _guard(() async {
    final rows = await _supabase
        .from('match_comments')
        .select(
          'id, match_id, parent_id, profile_id, body, created_at, '
          'profiles(name, avatar_url)',
        )
        .eq('match_id', thread.matchId)
        .eq('topic', thread.topic.dbName)
        .order('created_at');
    return [
      for (final row in rows)
        Comment(
          id: row['id'] as String,
          subjectId: row['match_id'] as String,
          parentId: row['parent_id'] as String?,
          authorId: row['profile_id'] as String,
          body: row['body'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          authorName: (row['profiles'] as Map<String, dynamic>?)?['name'] as String?,
          authorPhotoUrl: (row['profiles'] as Map<String, dynamic>?)?['avatar_url'] as String?,
        ),
    ];
  });

  @override
  Future<void> addComment(MatchThread thread, {required String body, String? parentId}) => _guard(
    () => _supabase.rpc(
      'add_match_comment',
      params: {
        'p_match_id': thread.matchId,
        'p_topic': thread.topic.dbName,
        'p_parent_id': parentId,
        'p_body': body,
      },
    ),
  );

  @override
  Future<void> deleteComment(String commentId) =>
      _guard(() => _supabase.rpc('delete_match_comment', params: {'p_id': commentId}));
}
