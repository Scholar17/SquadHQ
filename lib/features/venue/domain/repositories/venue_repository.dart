import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/venue.dart';
import '../usecases/save_venue.dart';

abstract interface class VenueRepository {
  /// [teamId]'s venues on its list (not archived), most recently used
  /// first.
  Future<Either<Failure, List<Venue>>> getTeamVenues(String teamId);

  /// One venue, archived or not — a match's details.
  Future<Either<Failure, Venue>> getVenue(String venueId);

  /// Adds ([SaveVenueParams.id] null) or edits a venue. Team admins only.
  Future<Either<Failure, Venue>> saveVenue(SaveVenueParams params);

  /// Takes it off the list; matches at it keep showing it.
  Future<Either<Failure, Unit>> archiveVenue(String venueId);
}
