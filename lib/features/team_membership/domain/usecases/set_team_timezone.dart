import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/team_membership_repository.dart';

class SetTeamTimezoneParams extends Equatable {
  const SetTeamTimezoneParams({required this.teamId, required this.timezone});

  final String teamId;
  final String timezone;

  @override
  List<Object?> get props => [teamId, timezone];
}

class SetTeamTimezone implements UseCase<Unit, SetTeamTimezoneParams> {
  const SetTeamTimezone(this._repository);

  final TeamMembershipRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SetTeamTimezoneParams params) =>
      _repository.setTeamTimezone(teamId: params.teamId, timezone: params.timezone);
}
