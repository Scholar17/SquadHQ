import 'package:equatable/equatable.dart';

import 'team.dart';

/// One row of a team's roster — a teammate's name/avatar plus their role
/// on that specific team.
class TeamMember extends Equatable {
  const TeamMember({
    required this.profileId,
    required this.name,
    required this.role,
    this.username,
    this.avatarUrl,
  });

  final String profileId;
  final String name;
  final TeamRole role;

  /// Their @mention name; null if not set.
  final String? username;
  final String? avatarUrl;

  @override
  List<Object?> get props => [profileId, name, role, username, avatarUrl];
}
