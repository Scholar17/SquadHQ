import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/venue.dart';
import '../repositories/venue_repository.dart';

class GetTeamVenues implements UseCase<List<Venue>, String> {
  const GetTeamVenues(this._repository);

  final VenueRepository _repository;

  @override
  Future<Either<Failure, List<Venue>>> call(String teamId) => _repository.getTeamVenues(teamId);
}
