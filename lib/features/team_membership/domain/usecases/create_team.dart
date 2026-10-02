import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/team.dart';
import '../repositories/team_membership_repository.dart';

class CreateTeam implements UseCase<Team, CreateTeamParams> {
  const CreateTeam(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, Team>> call(CreateTeamParams params) =>
      _repository.createTeam(params.name, kind: params.kind, currency: params.currency);
}

class CreateTeamParams extends Equatable {
  const CreateTeamParams({
    required this.name,
    this.kind = GroupKind.team,
    this.currency = GroupCurrency.thb,
  });

  final String name;
  final GroupKind kind;
  final GroupCurrency currency;

  @override
  List<Object?> get props => [name, kind, currency];
}
