import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/match.dart';
import '../repositories/match_repository.dart';

class GetUpcomingMatches implements UseCase<List<Match>, String> {
  const GetUpcomingMatches(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, List<Match>>> call(String teamId) =>
      _repository.getUpcomingMatches(teamId);
}
