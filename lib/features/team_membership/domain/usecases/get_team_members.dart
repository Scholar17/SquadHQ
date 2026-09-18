import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/team_member.dart';
import '../repositories/team_membership_repository.dart';

class GetTeamMembers implements UseCase<List<TeamMember>, String> {
  const GetTeamMembers(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, List<TeamMember>>> call(String teamId) =>
      _repository.getTeamMembers(teamId);
}
