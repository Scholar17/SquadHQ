import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/player_rating.dart';

abstract interface class PlayerRatingRemoteDataSource {
  Future<List<RatedPlayer>> getTeamRatings(String teamId);

  Future<PlayerRating?> getMyRating();

  Future<List<RatingPosition>> getPositions();

  Future<List<RatingQuestion>> getQuestions(String mainPosition);

  Future<PlayerRating> submitRating({
    required List<String> positions,
    required List<String> answerIds,
  });

  Future<PlayerRating> improveRating();

  Future<MatchStats> getMyMatchStats(String matchId);

  Future<void> logMatchStats(String matchId, MatchStats stats);
}

/// supabase/sql/045_player_ratings.sql and 046_fair_level_ups.sql.
class PlayerRatingRemoteDataSourceImpl implements PlayerRatingRemoteDataSource {
  PlayerRatingRemoteDataSourceImpl({required SupabaseClient supabaseClient})
    : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;

  /// A player_ratings row (or a get_team_ratings row) as a card; null
  /// when the row has no rating.
  static PlayerRating? _rating(Map<String, dynamic> row) {
    final positions = row['positions'] as List<dynamic>?;
    if (positions == null || row['ovr'] == null) return null;
    return PlayerRating(
      positions: [for (final code in positions) code as String],
      stats: {for (final key in StatKey.values) key: _int(row[key.name])},
      ovr: _int(row['ovr']),
      ratedAt: DateTime.parse(row['rated_at'] as String),
      improvements: _int(row['improvements']),
    );
  }

  @override
  Future<List<RatedPlayer>> getTeamRatings(String teamId) => _guard(() async {
    final rows = await _supabase.rpc<List<dynamic>>(
      'get_team_ratings',
      params: {'p_team_id': teamId},
    );
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        RatedPlayer(
          profileId: row['profile_id'] as String,
          name: row['name'] as String,
          avatarUrl: row['avatar_url'] as String?,
          rating: _rating(row),
          apps: _int(row['apps']),
          goals: _int(row['goals']),
          assists: _int(row['assists']),
          saves: _int(row['saves']),
          tackles: _int(row['tackles']),
          cleanSheets: _int(row['clean_sheets']),
          progress: _int(row['progress']),
        ),
    ];
  });

  @override
  Future<PlayerRating?> getMyRating() => _guard(() async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return null;
    final row = await _supabase.from('player_ratings').select().eq('profile_id', me).maybeSingle();
    return row == null ? null : _rating(row);
  });

  @override
  Future<List<RatingPosition>> getPositions() => _guard(() async {
    final rows = await _supabase.rpc<List<dynamic>>('get_rating_positions');
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        RatingPosition(
          code: row['code'] as String,
          name: row['name'] as String,
          group: PositionGroup.fromDb(row['category'] as String),
        ),
    ];
  });

  @override
  Future<List<RatingQuestion>> getQuestions(String mainPosition) => _guard(() async {
    final rows = await _supabase.rpc<List<dynamic>>(
      'get_rating_questions',
      params: {'p_main_position': mainPosition},
    );
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        RatingQuestion(
          id: row['id'] as String,
          body: row['body'] as String,
          answers: [
            for (final answer in (row['answers'] as List<dynamic>).cast<Map<String, dynamic>>())
              RatingAnswer(id: answer['id'] as String, body: answer['body'] as String),
          ],
        ),
    ];
  });

  @override
  Future<PlayerRating> submitRating({
    required List<String> positions,
    required List<String> answerIds,
  }) => _guard(() async {
    final row = await _supabase.rpc<Map<String, dynamic>>(
      'submit_player_rating',
      params: {'p_positions': positions, 'p_answer_ids': answerIds},
    );
    return _rating(row)!;
  });

  @override
  Future<PlayerRating> improveRating() => _guard(() async {
    final row = await _supabase.rpc<Map<String, dynamic>>('improve_player_rating');
    return _rating(row)!;
  });

  @override
  Future<MatchStats> getMyMatchStats(String matchId) => _guard(() async {
    final rows = await _supabase.rpc<List<dynamic>>(
      'get_my_match_stats',
      params: {'p_match_id': matchId},
    );
    if (rows.isEmpty) return const MatchStats();
    final row = rows.first as Map<String, dynamic>;
    return MatchStats(
      goals: _int(row['goals']),
      assists: _int(row['assists']),
      saves: _int(row['saves']),
      tackles: _int(row['tackles']),
      logged: row['logged'] as bool? ?? false,
      cleanSheet: row['clean_sheet'] as bool?,
      group: switch (row['position_group']) {
        final String group => PositionGroup.fromDb(group),
        _ => null,
      },
    );
  });

  @override
  Future<void> logMatchStats(String matchId, MatchStats stats) => _guard(
    () => _supabase.rpc(
      'log_match_stats',
      params: {
        'p_match_id': matchId,
        'p_goals': stats.goals,
        'p_assists': stats.assists,
        'p_saves': stats.saves,
        'p_tackles': stats.tackles,
      },
    ),
  );
}
