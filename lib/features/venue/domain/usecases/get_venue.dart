import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/venue.dart';
import '../repositories/venue_repository.dart';

class GetVenue implements UseCase<Venue, String> {
  const GetVenue(this._repository);

  final VenueRepository _repository;

  @override
  Future<Either<Failure, Venue>> call(String venueId) => _repository.getVenue(venueId);
}
