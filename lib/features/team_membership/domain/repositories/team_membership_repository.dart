import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/team.dart';
import '../entities/team_member.dart';

abstract interface class TeamMembershipRepository {
  /// Fails if the profile is already on 3 teams.
  /// The new team's time zone comes from the creator's phone.
  Future<Either<Failure, Team>> createTeam(
    String name, {
    GroupKind kind = GroupKind.team,
    GroupCurrency currency = GroupCurrency.thb,
  });

  /// Super admin only — see `set_team_timezone` in
  /// supabase/sql/011_team_timezone.sql.
  Future<Either<Failure, Unit>> setTeamTimezone({
    required String teamId,
    required String timezone,
  });

  /// Fails if the profile is already on 3 teams, or already on this team.
  Future<Either<Failure, Team>> joinTeam(String inviteCode);

  /// All teams the signed-in profile belongs to (0-3), each flagged with
  /// whether it's the active one.
  Future<Either<Failure, List<Team>>> getMyTeams();

  Future<Either<Failure, Unit>> switchActiveTeam(String teamId);

  Future<Either<Failure, List<TeamMember>>> getTeamMembers(String teamId);

  /// Caller must be the team's super admin, and [role] must not be
  /// [TeamRole.superAdmin] — see `set_team_member_role` in
  /// supabase/sql/002_create_teams.sql for the enforced rules.
  Future<Either<Failure, Unit>> setMemberRole({
    required String teamId,
    required String profileId,
    required TeamRole role,
  });

  /// Caller must be the team's super admin.
  Future<Either<Failure, Unit>> deleteTeam(String teamId);
}
