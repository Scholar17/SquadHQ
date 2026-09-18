import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../models/match_model.dart';

abstract interface class MatchRemoteDataSource {
  Future<List<MatchModel>> getUpcomingMatches(String teamId);

  Future<MatchModel> createMatch({
    required String teamId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    double? feePerPlayer,
  });
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
          .order('kickoff_at');
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
    double? feePerPlayer,
  }) async {
    try {
      final row = await _supabase.rpc('create_match', params: {
        'p_team_id': teamId,
        'p_opponent': opponent,
        'p_kickoff_at': kickoffAt.toUtc().toIso8601String(),
        'p_venue': venue,
        'p_fee_per_player': feePerPlayer,
      }) as Map<String, dynamic>;
      return MatchModel.fromRow(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }
}
