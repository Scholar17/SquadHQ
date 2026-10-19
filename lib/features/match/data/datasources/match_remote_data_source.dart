import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/match_history.dart';
import '../../domain/entities/match_questions.dart';
import '../../domain/entities/matchday_player.dart';
import '../models/match_model.dart';
import '../models/matchday_player_model.dart';

abstract interface class MatchRemoteDataSource {
  Future<List<MatchModel>> getUpcomingMatches(String teamId);

  Future<MatchModel> createMatch({
    required String teamId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    String? venueId,
    required int durationMinutes,
    int? playersNeeded,
  });

  Future<MatchModel> updateMatch({
    required String matchId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    String? venueId,
    required int durationMinutes,
    int? playersNeeded,
  });

  Future<void> deleteMatch(String matchId);

  /// Every member of [teamId] with their RSVP to [matchId].
  Future<List<MatchdayPlayerModel>> getMatchdayRoster({
    required String teamId,
    required String matchId,
  });

  Future<void> setRsvp({required String matchId, required RsvpAnswer answer});

  /// [teamId]'s matches that have kicked off (newest first), with RSVPs
  /// and Man of the Match votes, plus the team's members.
  Future<MatchHistory> getMatchHistory(String teamId);

  /// Saves game [gameNo] (null adds the next one); null scores = Not sure.
  Future<void> saveMatchGame({
    required String matchId,
    int? gameNo,
    int? ourScore,
    int? theirScore,
  });

  Future<void> removeMatchGame({required String matchId, required int gameNo});

  /// A Maybe player's "Did you play today?".
  Future<void> setMatchPlayed({required String matchId, required bool played});

  Future<void> submitMatchAnswers({required String matchId, required MatchAnswers answers});

  /// The caller's own answers to [matchId], or null before they answer.
  Future<MatchAnswers?> getMyMatchAnswers(String matchId);

  Future<void> voteMotm({required String matchId, required String nomineeId});

  Future<void> nudgeMatchRsvp(String matchId);
}

class MatchRemoteDataSourceImpl implements MatchRemoteDataSource {
  MatchRemoteDataSourceImpl({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  @override
  Future<List<MatchModel>> getUpcomingMatches(String teamId) async {
    try {
      final rows = await _supabase
          .from('matches')
          .select()
          .eq('team_id', teamId)
          .gte('kickoff_at', DateTime.now().toUtc().toIso8601String())
          // postgrest-dart sorts descending unless told otherwise — soonest
          // first is what "upcoming" needs.
          .order('kickoff_at', ascending: true);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(MatchModel.fromRow)
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<MatchModel> createMatch({
    required String teamId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    String? venueId,
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    try {
      final row = await _supabase.rpc('create_match', params: {
        'p_team_id': teamId,
        'p_opponent': opponent,
        'p_kickoff_at': kickoffAt.toUtc().toIso8601String(),
        'p_venue': venue,
        // Only with a saved venue picked, so a typed venue still works on
        // a database without 052.
        'p_venue_id': ?venueId,
        'p_duration_minutes': durationMinutes,
        'p_players_needed': playersNeeded,
      }) as Map<String, dynamic>;
      return MatchModel.fromRow(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<MatchModel> updateMatch({
    required String matchId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    String? venueId,
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    try {
      final row = await _supabase.rpc('update_match', params: {
        'p_match_id': matchId,
        'p_opponent': opponent,
        'p_kickoff_at': kickoffAt.toUtc().toIso8601String(),
        'p_venue': venue,
        // Only with a saved venue picked, so a typed venue still works on
        // a database without 052.
        'p_venue_id': ?venueId,
        'p_duration_minutes': durationMinutes,
        'p_players_needed': playersNeeded,
      }) as Map<String, dynamic>;
      return MatchModel.fromRow(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> deleteMatch(String matchId) async {
    try {
      await _supabase.rpc('delete_match', params: {'p_match_id': matchId});
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<MatchdayPlayerModel>> getMatchdayRoster({
    required String teamId,
    required String matchId,
  }) async {
    try {
      final (memberRows, rsvpRows) = await (
        _supabase
            .from('team_members')
            .select('profile_id, profiles(name, avatar_url)')
            .eq('team_id', teamId),
        _supabase.from('match_rsvps').select('profile_id, status').eq('match_id', matchId),
      ).wait;
      final statusByProfile = {
        for (final row in (rsvpRows as List<dynamic>).cast<Map<String, dynamic>>())
          row['profile_id'] as String: row['status'] as String,
      };
      return (memberRows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => MatchdayPlayerModel.fromRow(
                row,
                status: statusByProfile[row['profile_id']],
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> setRsvp({required String matchId, required RsvpAnswer answer}) async {
    try {
      await _supabase.rpc('set_match_rsvp', params: {
        'p_match_id': matchId,
        'p_status': answer.name,
      });
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  /// How many past matches the history loads.
  static const _historyLimit = 50;

  @override
  Future<MatchHistory> getMatchHistory(String teamId) async {
    final me = _supabase.auth.currentUser?.id;
    try {
      final (memberRows, matchRows, teamRow) = await (
        _supabase
            .from('team_members')
            .select('profile_id, profiles(name, avatar_url)')
            .eq('team_id', teamId),
        _supabase
            .from('matches')
            .select(
              '*, match_rsvps(profile_id, status, played), motm_votes(voter_id, nominee_id), '
              'match_games(game_no, our_score, their_score, updated_by, updated_at), '
              // Only the caller's own row is readable (053).
              'match_answers(profile_id)',
            )
            .eq('team_id', teamId)
            .lt('kickoff_at', DateTime.now().toUtc().toIso8601String())
            .order('kickoff_at', ascending: false)
            .limit(_historyLimit),
        _supabase.from('teams').select('timezone').eq('id', teamId).maybeSingle(),
      ).wait;
      return MatchHistory(
        timezone: teamRow?['timezone'] as String? ?? 'Asia/Bangkok',
        members: (memberRows as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(MatchdayPlayerModel.fromRow)
            .toList(),
        matches: [
          for (final row in (matchRows as List<dynamic>).cast<Map<String, dynamic>>())
            PastMatch(
              match: MatchModel.fromRow(row),
              answers: {
                for (final rsvp in (row['match_rsvps'] as List<dynamic>? ?? const [])
                    .cast<Map<String, dynamic>>())
                  rsvp['profile_id'] as String: ?rsvpAnswerFromDb(rsvp['status'] as String?),
              },
              motmVotes: {
                for (final vote in (row['motm_votes'] as List<dynamic>? ?? const []))
                  (vote as Map<String, dynamic>)['voter_id'] as String:
                      vote['nominee_id'] as String,
              },
              played: {
                for (final rsvp in (row['match_rsvps'] as List<dynamic>? ?? const [])
                    .cast<Map<String, dynamic>>())
                  if (rsvp['played'] case final bool played) rsvp['profile_id'] as String: played,
              },
              games: [
                for (final game in (row['match_games'] as List<dynamic>? ?? const [])
                    .cast<Map<String, dynamic>>())
                  MatchGame(
                    gameNo: (game['game_no'] as num).toInt(),
                    ourScore: (game['our_score'] as num?)?.toInt(),
                    theirScore: (game['their_score'] as num?)?.toInt(),
                    updatedBy: game['updated_by'] as String?,
                    updatedAt: switch (game['updated_at']) {
                      final String at => DateTime.parse(at),
                      _ => null,
                    },
                  ),
              ]..sort((a, b) => a.gameNo.compareTo(b.gameNo)),
              answeredByMe: (row['match_answers'] as List<dynamic>? ?? const []).any(
                (answer) => (answer as Map<String, dynamic>)['profile_id'] == me,
              ),
            ),
        ],
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  Future<void> _rpc(String function, Map<String, dynamic> params) async {
    try {
      await _supabase.rpc(function, params: params);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> saveMatchGame({
    required String matchId,
    int? gameNo,
    int? ourScore,
    int? theirScore,
  }) => _rpc('save_match_game', {
    'p_match_id': matchId,
    'p_game_no': gameNo,
    'p_our_score': ourScore,
    'p_their_score': theirScore,
  });

  @override
  Future<void> removeMatchGame({required String matchId, required int gameNo}) =>
      _rpc('remove_match_game', {'p_match_id': matchId, 'p_game_no': gameNo});

  @override
  Future<void> setMatchPlayed({required String matchId, required bool played}) =>
      _rpc('set_match_played', {'p_match_id': matchId, 'p_played': played});

  @override
  Future<void> submitMatchAnswers({required String matchId, required MatchAnswers answers}) =>
      _rpc('submit_match_answers', {
        'p_match_id': matchId,
        'p_position': answers.position.name,
        'p_a1': answers.answers[0],
        'p_a2': answers.answers[1],
        'p_a3': answers.answers[2],
        'p_pick_id': answers.pickId,
      });

  @override
  Future<MatchAnswers?> getMyMatchAnswers(String matchId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return null;
    try {
      final row = await _supabase
          .from('match_answers')
          .select()
          .eq('match_id', matchId)
          .eq('profile_id', me)
          .maybeSingle();
      final position = PlayedPosition.fromDb(row?['position'] as String?);
      if (row == null || position == null) return null;
      return MatchAnswers(
        position: position,
        answers: [for (final key in ['a1', 'a2', 'a3']) (row[key] as num?)?.toInt()],
        pickId: row['pick_id'] as String?,
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> voteMotm({required String matchId, required String nomineeId}) async {
    try {
      await _supabase.rpc('vote_motm', params: {
        'p_match_id': matchId,
        'p_nominee_id': nomineeId,
      });
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> nudgeMatchRsvp(String matchId) async {
    try {
      await _supabase.rpc('nudge_match_rsvp', params: {'p_match_id': matchId});
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }
}
