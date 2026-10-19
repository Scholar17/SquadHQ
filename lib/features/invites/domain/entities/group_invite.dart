import 'package:equatable/equatable.dart';

import '../../../team_membership/domain/entities/team.dart';

/// An invitation to join a team or squad, waiting on the invitee
/// (supabase/sql/056_group_invites.sql).
class GroupInvite extends Equatable {
  const GroupInvite({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.kind,
    required this.memberCount,
    required this.invitedByName,
    required this.createdAt,
  });

  final String id;
  final String teamId;
  final String teamName;
  final GroupKind kind;
  final int memberCount;

  /// Null if the admin who sent it has since deleted their account.
  final String? invitedByName;
  final DateTime createdAt;

  bool get isSquad => kind == GroupKind.squad;

  @override
  List<Object?> get props => [id, teamId, teamName, kind, memberCount, invitedByName, createdAt];
}

/// Someone an admin can invite: they share a group with the admin, and
/// aren't in this one. [invited]: already has a pending invite to it.
class InviteCandidate extends Equatable {
  const InviteCandidate({
    required this.profileId,
    required this.name,
    this.username,
    this.photoUrl,
    this.invited = false,
  });

  final String profileId;
  final String name;
  final String? username;
  final String? photoUrl;
  final bool invited;

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  InviteCandidate asInvited() => InviteCandidate(
    profileId: profileId,
    name: name,
    username: username,
    photoUrl: photoUrl,
    invited: true,
  );

  @override
  List<Object?> get props => [profileId, name, username, photoUrl, invited];
}
