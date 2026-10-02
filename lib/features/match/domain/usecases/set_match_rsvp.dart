import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/matchday_player.dart';
import '../repositories/match_repository.dart';

class SetMatchRsvpParams extends Equatable {
  const SetMatchRsvpParams({required this.matchId, required this.answer});

  final String matchId;
  final RsvpAnswer answer;

  @override
  List<Object?> get props => [matchId, answer];
}

class SetMatchRsvp implements UseCase<Unit, SetMatchRsvpParams> {
  const SetMatchRsvp(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SetMatchRsvpParams params) =>
      _repository.setRsvp(matchId: params.matchId, answer: params.answer);
}
