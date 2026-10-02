import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/match_repository.dart';

class DeleteMatch implements UseCase<Unit, String> {
  const DeleteMatch(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String matchId) => _repository.deleteMatch(matchId);
}
