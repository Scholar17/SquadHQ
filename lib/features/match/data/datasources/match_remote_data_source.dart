import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/match_history.dart';
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
    required int durationMinutes,
    int? playersNeeded,
  });

  Future<MatchModel> updateMatch({
    required String matchId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
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

  Future<void> setMatchScore({
    required String matchId,
    required int ourScore,
    required int theirScore,
  });

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
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    try {
      final row = await _supabase.rpc('create_match', params: {
        'p_team_id': teamId,
        'p_opponent': opponent,
        'p_kickoff_at': kickoffAt.toUtc().toIso8601String(),
        'p_venue': venue,
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
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    try {
      final row = await _supabase.rpc('update_match', params: {
        'p_match_id': matchId,
        'p_opponent': opponent,
        'p_kickoff_at': kickoffAt.toUtc().toIso8601String(),
        'p_venue': venue,
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
    try {
      final (memberRows, matchRows, teamRow) = await (
        _supabase
            .from('team_members')
            .select('profile_id, profiles(name, avatar_url)')
            .eq('team_id', teamId),
        _supabase
            .from('matches')
            .select('*, match_rsvps(profile_id, status), motm_votes(voter_id, nominee_id)')
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
            ),
        ],
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> setMatchScore({
    required String matchId,
    required int ourScore,
    required int theirScore,
  }) async {
    try {
      await _supabase.rpc('set_match_score', params: {
        'p_match_id': matchId,
        'p_our_score': ourScore,
        'p_their_score': theirScore,
      });
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
