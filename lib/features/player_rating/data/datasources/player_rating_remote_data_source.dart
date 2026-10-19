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
}

/// supabase/sql/045_player_ratings.sql, 046_fair_level_ups.sql and
/// 053_match_questions.sql.
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
      lastBoost: [
        for (final part in (row['last_boost'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          if (StatKey.values.where((key) => key.name == part['stat']).firstOrNull case final stat?)
            BoostPart(
              stat: stat,
              points: _int(part['points']),
              source: BoostSource.fromDb(part['source'] as String?),
            ),
      ],
      droppedAt: switch (row['dropped_at']) {
        final String at => DateTime.parse(at),
        _ => null,
      },
    );
  }

  @override
  Future<List<RatedPlayer>> getTeamRatings(String teamId) => _guard(() async {
    final rows = (await _supabase.rpc<List<dynamic>>(
      'get_team_ratings',
      params: {'p_team_id': teamId},
    )).cast<Map<String, dynamic>>();
    final usernames = await _usernames([for (final row in rows) row['profile_id'] as String]);
    return [
      for (final row in rows)
        RatedPlayer(
          profileId: row['profile_id'] as String,
          name: row['name'] as String,
          username: usernames[row['profile_id']],
          avatarUrl: row['avatar_url'] as String?,
          rating: _rating(row),
          apps: _int(row['apps']),
          goals: _int(row['goals']),
          assists: _int(row['assists']),
          saves: _int(row['saves']),
          tackles: _int(row['tackles']),
          cleanSheets: _int(row['clean_sheets']),
          motmWins: _int(row['motm_wins']),
          gamesWon: _int(row['games_won']),
          progress: _int(row['progress']),
        ),
    ];
  });

  /// @mention names by profile id — get_team_ratings doesn't return them,
  /// and teammates' profiles are readable. Optional: none if it fails.
  Future<Map<String, String>> _usernames(List<String> profileIds) async {
    if (profileIds.isEmpty) return const {};
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, username')
          .inFilter('id', profileIds);
      return {
        for (final row in rows)
          if (row['username'] case final String username) row['id'] as String: username,
      };
    } on PostgrestException {
      return const {};
    }
  }

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
}
