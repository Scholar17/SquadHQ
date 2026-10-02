import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/match_repository.dart';

class VoteMotmParams extends Equatable {
  const VoteMotmParams({required this.matchId, required this.nomineeId});

  final String matchId;
  final String nomineeId;

  @override
  List<Object?> get props => [matchId, nomineeId];
}

class VoteMotm implements UseCase<Unit, VoteMotmParams> {
  const VoteMotm(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(VoteMotmParams params) =>
      _repository.voteMotm(matchId: params.matchId, nomineeId: params.nomineeId);
}
