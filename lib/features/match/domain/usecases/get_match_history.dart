import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/match_history.dart';
import '../repositories/match_repository.dart';

class GetMatchHistory implements UseCase<MatchHistory, String> {
  const GetMatchHistory(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, MatchHistory>> call(String teamId) =>
      _repository.getMatchHistory(teamId);
}
