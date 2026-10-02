import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/matchday_player.dart';
import '../repositories/match_repository.dart';

class GetMatchdayRosterParams extends Equatable {
  const GetMatchdayRosterParams({required this.teamId, required this.matchId});

  final String teamId;
  final String matchId;

  @override
  List<Object?> get props => [teamId, matchId];
}

class GetMatchdayRoster implements UseCase<List<MatchdayPlayer>, GetMatchdayRosterParams> {
  const GetMatchdayRoster(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, List<MatchdayPlayer>>> call(GetMatchdayRosterParams params) =>
      _repository.getMatchdayRoster(teamId: params.teamId, matchId: params.matchId);
}
