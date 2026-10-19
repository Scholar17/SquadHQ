import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../team_membership/domain/entities/team.dart';
import '../../domain/entities/group_invite.dart';

abstract interface class InviteRemoteDataSource {
  Future<List<InviteCandidate>> searchCandidates(String teamId, String query);

  Future<void> invite(String teamId, String profileId);

  Future<List<GroupInvite>> myInvites();

  Future<void> respond(String inviteId, {required bool accept});
}

/// 056's invite_candidates, invite_to_team, my_group_invites and
/// respond_to_group_invite.
class InviteRemoteDataSourceImpl implements InviteRemoteDataSource {
  InviteRemoteDataSourceImpl({required SupabaseClient supabaseClient})
    : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  @override
  Future<List<InviteCandidate>> searchCandidates(String teamId, String query) async {
    try {
      final rows = await _supabase.rpc(
        'invite_candidates',
        params: {'p_team_id': teamId, 'p_query': query},
      ) as List;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          InviteCandidate(
            profileId: row['profile_id'] as String,
            name: row['name'] as String,
            username: row['username'] as String?,
            photoUrl: row['avatar_url'] as String?,
            invited: row['invited'] as bool? ?? false,
          ),
      ];
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> invite(String teamId, String profileId) async {
    try {
      await _supabase.rpc(
        'invite_to_team',
        params: {'p_team_id': teamId, 'p_profile_id': profileId},
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<GroupInvite>> myInvites() async {
    try {
      final rows = await _supabase.rpc('my_group_invites') as List;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          GroupInvite(
            id: row['id'] as String,
            teamId: row['team_id'] as String,
            teamName: row['team_name'] as String,
            kind: row['kind'] == 'squad' ? GroupKind.squad : GroupKind.team,
            memberCount: (row['member_count'] as num).toInt(),
            invitedByName: row['invited_by_name'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
      ];
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> respond(String inviteId, {required bool accept}) async {
    try {
      await _supabase.rpc(
        'respond_to_group_invite',
        params: {'p_invite_id': inviteId, 'p_accept': accept},
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }
}
