import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/team.dart';
import '../models/team_member_model.dart';
import '../models/team_model.dart';

abstract interface class TeamMembershipRemoteDataSource {
  Future<TeamModel> createTeam(String name, {GroupKind kind, GroupCurrency currency});

  Future<TeamModel> joinTeam(String inviteCode);

  Future<List<TeamModel>> getMyTeams();

  Future<void> switchActiveTeam(String teamId);

  Future<List<TeamMemberModel>> getTeamMembers(String teamId);

  Future<void> setMemberRole({
    required String teamId,
    required String profileId,
    required TeamRole role,
  });

  Future<void> deleteTeam(String teamId);

  Future<void> setTeamTimezone({required String teamId, required String timezone});
}

class TeamMembershipRemoteDataSourceImpl
    implements TeamMembershipRemoteDataSource {
  TeamMembershipRemoteDataSourceImpl({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  @override
  Future<TeamModel> createTeam(
    String name, {
    GroupKind kind = GroupKind.team,
    GroupCurrency currency = GroupCurrency.thb,
  }) async {
    try {
      final row = await _supabase.rpc(
        'create_team',
        params: {
          'p_name': name,
          'p_timezone': await _deviceTimezone(),
          'p_kind': kind.name,
          'p_currency': groupCurrencyToDb(currency),
        },
      ) as Map<String, dynamic>;
      return TeamModel.fromTeamRow(row, role: TeamRole.superAdmin, isActive: true);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<TeamModel> joinTeam(String inviteCode) async {
    try {
      final row = await _supabase.rpc(
        'join_team_by_invite_code',
        params: {'p_invite_code': inviteCode},
      ) as Map<String, dynamic>;
      return TeamModel.fromTeamRow(row, role: TeamRole.player, isActive: true);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<TeamModel>> getMyTeams() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final profileRow = await _supabase
          .from('profiles')
          .select('active_team_id')
          .eq('id', userId)
          .single();
      var activeTeamId = profileRow['active_team_id'] as String?;

      final rows = (await _supabase
              .from('team_members')
              .select('role, teams(*)')
              .eq('profile_id', userId)
              .order('joined_at'))
          .cast<Map<String, dynamic>>();

      // active_team_id can be null or stale while memberships remain —
      // e.g. the active team was deleted (its FK sets null) — which would
      // leave Home and Match with no team. Fall back to the earliest-joined
      // team and save it, so every screen agrees.
      final teamIds = [for (final row in rows) (row['teams'] as Map<String, dynamic>)['id']];
      if (teamIds.isNotEmpty && !teamIds.contains(activeTeamId)) {
        activeTeamId = teamIds.first as String;
        await switchActiveTeam(activeTeamId);
      }

      return rows
          .map(
            (row) =>
                TeamModel.fromMembershipRow(row, activeTeamId: activeTeamId),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> switchActiveTeam(String teamId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const ServerException('Not signed in.');
    }
    try {
      await _supabase
          .from('profiles')
          .update({'active_team_id': teamId})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<TeamMemberModel>> getTeamMembers(String teamId) async {
    try {
      final rows = await _supabase
          .from('team_members')
          .select('profile_id, role, profiles(name, avatar_url)')
          .eq('team_id', teamId);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(TeamMemberModel.fromRow)
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> setMemberRole({
    required String teamId,
    required String profileId,
    required TeamRole role,
  }) async {
    try {
      await _supabase.rpc('set_team_member_role', params: {
        'p_team_id': teamId,
        'p_profile_id': profileId,
        'p_role': teamRoleToDb(role),
      });
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> deleteTeam(String teamId) async {
    try {
      await _supabase.rpc('delete_team', params: {'p_team_id': teamId});
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  /// The phone's IANA time zone, for a new team's default — or null if the
  /// platform can't say (`create_team` then falls back to Asia/Bangkok).
  static Future<String?> _deviceTimezone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setTeamTimezone({required String teamId, required String timezone}) async {
    try {
      await _supabase.rpc('set_team_timezone', params: {
        'p_team_id': teamId,
        'p_timezone': timezone,
      });
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }
}
