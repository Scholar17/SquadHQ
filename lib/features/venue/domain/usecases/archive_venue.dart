import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/venue_repository.dart';

class ArchiveVenue implements UseCase<Unit, String> {
  const ArchiveVenue(this._repository);

  final VenueRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String venueId) => _repository.archiveVenue(venueId);
}
