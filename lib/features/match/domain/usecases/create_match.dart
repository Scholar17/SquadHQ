import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/match.dart';
import '../repositories/match_repository.dart';

class CreateMatchParams extends Equatable {
  const CreateMatchParams({
    required this.teamId,
    required this.opponent,
    required this.kickoffAt,
    this.venue,
    this.feePerPlayer,
  });

  final String teamId;
  final String opponent;
  final DateTime kickoffAt;
  final String? venue;
  final double? feePerPlayer;

  @override
  List<Object?> get props => [teamId, opponent, kickoffAt, venue, feePerPlayer];
}

class CreateMatch implements UseCase<Match, CreateMatchParams> {
  const CreateMatch(this._repository);

  final MatchRepository _repository;

  @override
  Future<Either<Failure, Match>> call(CreateMatchParams params) =>
      _repository.createMatch(
        teamId: params.teamId,
        opponent: params.opponent,
        kickoffAt: params.kickoffAt,
        venue: params.venue,
        feePerPlayer: params.feePerPlayer,
      );
}
