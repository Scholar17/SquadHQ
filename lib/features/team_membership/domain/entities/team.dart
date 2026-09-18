import 'package:equatable/equatable.dart';

/// - [superAdmin]: the team's creator. Can promote/demote between [admin]
///   and [player], and is the only one who can delete the team. Fixed at
///   creation — never reassigned.
/// - [admin]: promoted by the super admin. Can access team management, but
///   can't change anyone's role and can't delete the team.
/// - [player]: regular member.
enum TeamRole { superAdmin, admin, player }

class Team extends Equatable {
  const Team({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String name;
  final String inviteCode;
  final TeamRole role;

  /// Whether this is the profile's currently active team — the one that
  /// drives the dashboard. Exactly one of a profile's teams is active.
  final bool isActive;

  @override
  List<Object?> get props => [id, name, inviteCode, role, isActive];
}
