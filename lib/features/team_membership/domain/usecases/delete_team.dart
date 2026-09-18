import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/team_membership_repository.dart';

class DeleteTeam implements UseCase<Unit, String> {
  const DeleteTeam(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String teamId) =>
      _repository.deleteTeam(teamId);
}
