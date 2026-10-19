import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/group_invite.dart';

abstract interface class InviteRepository {
  /// People who share a group with you and aren't in [teamId], matching
  /// [query] by name or @username (blank: everyone). Admins only.
  Future<Either<Failure, List<InviteCandidate>>> searchCandidates(String teamId, String query);

  /// Invites [profileId] to [teamId]: they get a notification and a push.
  /// Inviting someone already invited does nothing.
  Future<Either<Failure, Unit>> invite(String teamId, String profileId);

  /// [teamId]'s invites still waiting on an answer, newest first. Admins
  /// only.
  Future<Either<Failure, List<PendingInvite>>> pendingInvites(String teamId);

  /// Withdraws a pending invite (any admin of its group).
  Future<Either<Failure, Unit>> cancel(String inviteId);

  /// Your pending invitations, newest first.
  Future<Either<Failure, List<GroupInvite>>> myInvites();

  /// Accepts (joins as a player, and makes it your active group) or
  /// declines [inviteId].
  Future<Either<Failure, Unit>> respond(String inviteId, {required bool accept});
}
