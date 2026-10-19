import 'package:dartz/dartz.dart';
import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/invites/domain/entities/group_invite.dart';
import 'package:squad_hq/features/invites/domain/repositories/invite_repository.dart';

/// In-memory 056: [people] are those sharing a group with you; [invites]
/// your pending invitations.
class FakeInviteRepository implements InviteRepository {
  final people = <InviteCandidate>[];
  final invites = <GroupInvite>[];

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
