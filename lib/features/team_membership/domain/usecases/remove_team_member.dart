import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/team_membership_repository.dart';

class RemoveTeamMemberParams extends Equatable {
  const RemoveTeamMemberParams({required this.teamId, required this.profileId});

  final String teamId;
  final String profileId;

  @override
  List<Object?> get props => [teamId, profileId];
}

class RemoveTeamMember implements UseCase<Unit, RemoveTeamMemberParams> {
  const RemoveTeamMember(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(RemoveTeamMemberParams params) =>
      _repository.removeMember(teamId: params.teamId, profileId: params.profileId);
}
