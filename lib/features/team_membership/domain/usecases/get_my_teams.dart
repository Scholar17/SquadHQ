import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/team.dart';
import '../repositories/team_membership_repository.dart';

class GetMyTeams implements UseCase<List<Team>, NoParams> {
  const GetMyTeams(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, List<Team>>> call(NoParams params) =>
      _repository.getMyTeams();
}
