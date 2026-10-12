import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/mention.dart';

abstract interface class MentionMembersRemoteDataSource {
  Future<List<MentionMember>> getMembers(String teamId);
}

/// A team's members, from team_members and their profiles (teammates can
/// read each other's — 005's profiles_select_teammates).
class MentionMembersRemoteDataSourceImpl implements MentionMembersRemoteDataSource {
  MentionMembersRemoteDataSourceImpl({required SupabaseClient supabaseClient})
    : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  @override
  Future<List<MentionMember>> getMembers(String teamId) async {
    try {
      final rows = await _supabase
          .from('team_members')
          .select('profile_id, profiles(name, username, avatar_url)')
          .eq('team_id', teamId);
      return [
        for (final row in rows)
          if (row['profiles'] case final Map<String, dynamic> profile)
            MentionMember(
              id: row['profile_id'] as String,
              name: (profile['name'] as String?) ?? 'Member',
              username: profile['username'] as String?,
              photoUrl: profile['avatar_url'] as String?,
            ),
      ];
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }
}
