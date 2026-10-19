import 'package:dartz/dartz.dart';
import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/invites/domain/entities/group_invite.dart';
import 'package:squad_hq/features/invites/domain/repositories/invite_repository.dart';

/// In-memory 056: [people] are those sharing a group with you; [invites]
/// your pending invitations.
class FakeInviteRepository implements InviteRepository {
  final people = <InviteCandidate>[];
  final invites = <GroupInvite>[];

  /// Each group's pending invites, by team id.
  final pending = <String, List<PendingInvite>>{};

  /// Invites cancelled, by id.
  final cancelled = <String>[];

  /// Invites sent, as (team id, profile id).
  final sent = <(String, String)>[];

  /// Answers given, as (invite id, accepted).
  final answers = <(String, bool)>[];

  /// Set to make the next answer fail with this message.
  String? failNextAnswer;

  void reset() {
    people.clear();
    invites.clear();
    sent.clear();
    answers.clear();
    pending.clear();
    cancelled.clear();
    failNextAnswer = null;
  }

  @override
  Future<Either<Failure, List<InviteCandidate>>> searchCandidates(String teamId, String query) async {
    final q = query.toLowerCase();
    final handle = q.startsWith('@') ? q.substring(1) : q;
    return Right([
      for (final person in people)
        if (q.isEmpty ||
            person.name.toLowerCase().contains(q) ||
            (person.username?.toLowerCase().startsWith(handle) ?? false))
          sent.contains((teamId, person.profileId)) ? person.asInvited() : person,
    ]);
  }

  @override
  Future<Either<Failure, Unit>> invite(String teamId, String profileId) async {
    sent.add((teamId, profileId));
    final person = people.firstWhere((p) => p.profileId == profileId);
    (pending[teamId] ??= []).add(
      PendingInvite(
        id: 'inv-$profileId',
        profileId: profileId,
        name: person.name,
        username: person.username,
        invitedByName: 'Test Player',
        createdAt: DateTime.now(),
      ),
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<PendingInvite>>> pendingInvites(String teamId) async =>
      Right([...?pending[teamId]]);

  @override
  Future<Either<Failure, Unit>> cancel(String inviteId) async {
    cancelled.add(inviteId);
    for (final list in pending.values) {
      list.removeWhere((invite) => invite.id == inviteId);
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<GroupInvite>>> myInvites() async => Right([...invites]);

  @override
  Future<Either<Failure, Unit>> respond(String inviteId, {required bool accept}) async {
    if (failNextAnswer case final message?) {
      failNextAnswer = null;
      return Left(ServerFailure(message));
    }
    answers.add((inviteId, accept));
    invites.removeWhere((invite) => invite.id == inviteId);
    return const Right(unit);
  }
}
