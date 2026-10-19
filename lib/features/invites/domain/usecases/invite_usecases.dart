import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/group_invite.dart';
import '../repositories/invite_repository.dart';

typedef InviteSearchParams = ({String teamId, String query});
typedef InviteParams = ({String teamId, String profileId});
typedef InviteResponseParams = ({String inviteId, bool accept});

class SearchInviteCandidates implements UseCase<List<InviteCandidate>, InviteSearchParams> {
  const SearchInviteCandidates(this._repository);

  final InviteRepository _repository;

  @override
  Future<Either<Failure, List<InviteCandidate>>> call(InviteSearchParams params) =>
      _repository.searchCandidates(params.teamId, params.query);
}

class InviteToGroup implements UseCase<Unit, InviteParams> {
  const InviteToGroup(this._repository);

  final InviteRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(InviteParams params) =>
      _repository.invite(params.teamId, params.profileId);
}

/// A group's pending invites ([String] is its team id).
class GetPendingInvites implements UseCase<List<PendingInvite>, String> {
  const GetPendingInvites(this._repository);

  final InviteRepository _repository;

  @override
  Future<Either<Failure, List<PendingInvite>>> call(String teamId) =>
      _repository.pendingInvites(teamId);
}

/// Withdraws a pending invite ([String] is its id).
class CancelInvite implements UseCase<Unit, String> {
  const CancelInvite(this._repository);

  final InviteRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String inviteId) => _repository.cancel(inviteId);
}

class GetMyInvites implements UseCase<List<GroupInvite>, NoParams> {
  const GetMyInvites(this._repository);

  final InviteRepository _repository;

  @override
  Future<Either<Failure, List<GroupInvite>>> call(NoParams params) => _repository.myInvites();
}

class RespondToInvite implements UseCase<Unit, InviteResponseParams> {
  const RespondToInvite(this._repository);

  final InviteRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(InviteResponseParams params) =>
      _repository.respond(params.inviteId, accept: params.accept);
}
