import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/team.dart';
import '../models/team_member_model.dart';
import '../models/team_model.dart';

abstract interface class TeamMembershipRemoteDataSource {
  Future<TeamModel> createTeam(String name);

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
}

class TeamMembershipRemoteDataSourceImpl
    implements TeamMembershipRemoteDataSource {
  TeamMembershipRemoteDataSourceImpl({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  @override
  Future<TeamModel> createTeam(String name) async {
    try {
      final row = await _supabase
          .rpc('create_team', params: {'p_name': name}) as Map<String, dynamic>;
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
      final activeTeamId = profileRow['active_team_id'] as String?;

      final rows = await _supabase
          .from('team_members')
          .select('role, teams(*)')
          .eq('profile_id', userId);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
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
}
