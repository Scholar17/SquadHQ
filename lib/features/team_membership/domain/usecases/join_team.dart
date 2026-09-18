import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/team.dart';
import '../repositories/team_membership_repository.dart';

class JoinTeam implements UseCase<Team, String> {
  const JoinTeam(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, Team>> call(String inviteCode) =>
      _repository.joinTeam(inviteCode);
}
