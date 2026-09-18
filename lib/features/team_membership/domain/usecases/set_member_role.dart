import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/team.dart';
import '../repositories/team_membership_repository.dart';

class SetMemberRoleParams extends Equatable {
  const SetMemberRoleParams({
    required this.teamId,
    required this.profileId,
    required this.role,
  });

  final String teamId;
  final String profileId;
  final TeamRole role;

  @override
  List<Object?> get props => [teamId, profileId, role];
}

class SetMemberRole implements UseCase<Unit, SetMemberRoleParams> {
  const SetMemberRole(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SetMemberRoleParams params) =>
      _repository.setMemberRole(
        teamId: params.teamId,
        profileId: params.profileId,
        role: params.role,
      );
}
