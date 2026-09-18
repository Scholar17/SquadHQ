import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/team_membership_repository.dart';

class SwitchActiveTeam implements UseCase<Unit, String> {
  const SwitchActiveTeam(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String teamId) =>
      _repository.switchActiveTeam(teamId);
}
