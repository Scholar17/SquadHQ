import '../../domain/entities/team_member.dart';
import 'team_model.dart';

class TeamMemberModel extends TeamMember {
  const TeamMemberModel({
    required super.profileId,
    required super.name,
    required super.role,
    super.avatarUrl,
  });

  /// Builds from a `team_members` row with its `profiles` relation
  /// embedded, e.g. `.select('profile_id, role, profiles(name, avatar_url)')`.
  factory TeamMemberModel.fromRow(Map<String, dynamic> row) {
    final profileRow = row['profiles'] as Map<String, dynamic>;
    return TeamMemberModel(
      profileId: row['profile_id'] as String,
      name: profileRow['name'] as String,
      avatarUrl: profileRow['avatar_url'] as String?,
      role: teamRoleFromDb(row['role'] as String),
    );
  }
}
