import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/team_membership_repository.dart';

class LeaveTeamParams extends Equatable {
  const LeaveTeamParams({required this.teamId, this.newOwnerId});

  final String teamId;

  /// Who becomes super admin — needed when the super admin leaves.
  final String? newOwnerId;

  @override
  List<Object?> get props => [teamId, newOwnerId];
}

class LeaveTeam implements UseCase<Unit, LeaveTeamParams> {
  const LeaveTeam(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(LeaveTeamParams params) =>
      _repository.leaveTeam(params.teamId, newOwnerId: params.newOwnerId);
}
