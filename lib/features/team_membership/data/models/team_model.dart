import '../../domain/entities/team.dart';

TeamRole teamRoleFromDb(String value) => switch (value) {
      'super_admin' => TeamRole.superAdmin,
      'admin' => TeamRole.admin,
      _ => TeamRole.player,
    };

GroupKind groupKindFromDb(String? value) => value == 'squad' ? GroupKind.squad : GroupKind.team;

GroupCurrency groupCurrencyFromDb(String? value) =>
    value == 'MMK' ? GroupCurrency.mmk : GroupCurrency.thb;

String groupCurrencyToDb(GroupCurrency currency) => switch (currency) {
      GroupCurrency.thb => 'THB',
      GroupCurrency.mmk => 'MMK',
    };

String teamRoleToDb(TeamRole role) => switch (role) {
      TeamRole.superAdmin => 'super_admin',
      TeamRole.admin => 'admin',
      TeamRole.player => 'player',
    };

class TeamModel extends Team {
  const TeamModel({
    required super.id,
    required super.name,
    required super.inviteCode,
    required super.role,
    required super.isActive,
    super.timezone,
    super.kind,
    super.currency,
  });

  /// Builds from a raw `teams` row (as returned by the `create_team` /
  /// `join_team_by_invite_code` RPCs) plus the role/active flag the caller
  /// already knows from context — those RPCs don't return them.
  factory TeamModel.fromTeamRow(
    Map<String, dynamic> row, {
    required TeamRole role,
    required bool isActive,
  }) =>
      TeamModel(
        id: row['id'] as String,
        name: row['name'] as String,
        inviteCode: row['invite_code'] as String,
        role: role,
        isActive: isActive,
        timezone: row['timezone'] as String? ?? Team.defaultTimezone,
        kind: groupKindFromDb(row['kind'] as String?),
        currency: groupCurrencyFromDb(row['currency'] as String?),
      );

  /// Builds from a `team_members` row with its `teams` relation embedded,
  /// e.g. `.select('role, teams(*)')`.
  factory TeamModel.fromMembershipRow(
    Map<String, dynamic> row, {
    required String? activeTeamId,
  }) {
    final teamRow = row['teams'] as Map<String, dynamic>;
    return TeamModel.fromTeamRow(
      teamRow,
      role: teamRoleFromDb(row['role'] as String),
      isActive: teamRow['id'] == activeTeamId,
    );
  }
}
