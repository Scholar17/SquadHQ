import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/venue/domain/entities/venue.dart';
import 'package:squad_hq/features/venue/domain/repositories/venue_repository.dart';
import 'package:squad_hq/features/venue/domain/usecases/save_venue.dart';

/// team-1's saved venues, in memory.
class FakeVenueRepository implements VenueRepository {
  final List<Venue> venues = [];

  void reset() {
    venues
      ..clear()
      ..addAll(const [
        Venue(
          id: 'v-arena',
          teamId: 'team-1',
          name: 'Arena 5 Rama 9',
          mapsUrl: 'https://maps.app.goo.gl/arena5',
          latitude: 13.7563,
          longitude: 100.5018,
          notes: 'Pitch 3 — park behind the 7-Eleven',
          pricePerHour: 1200,
        ),
        Venue(id: 'v-polo', teamId: 'team-1', name: 'Polo Football Park'),
      ]);
  }

  @override
  Future<Either<Failure, List<Venue>>> getTeamVenues(String teamId) async =>
      Right([for (final venue in venues) if (venue.teamId == teamId && !venue.archived) venue]);

  @override
  Future<Either<Failure, Venue>> getVenue(String venueId) async =>
      Right(venues.firstWhere((venue) => venue.id == venueId));

  @override
  Future<Either<Failure, Venue>> saveVenue(SaveVenueParams params) async {
    final taken = venues.any(
      (venue) =>
          venue.id != params.id &&
          !venue.archived &&
          venue.name.toLowerCase() == params.name.trim().toLowerCase(),
    );
    if (taken) return const Left(ServerFailure('Your team already has a venue with that name.'));
    final venue = Venue(
      id: params.id ?? 'v-${venues.length + 1}',
      teamId: params.teamId,
      name: params.name.trim(),
      mapsUrl: params.mapsUrl,
      latitude: params.latitude,
      longitude: params.longitude,
      notes: params.notes,
      pricePerHour: params.pricePerHour,
    );
    venues
      ..removeWhere((existing) => existing.id == venue.id)
      ..add(venue);
    return Right(venue);
  }

  @override
  Future<Either<Failure, Unit>> archiveVenue(String venueId) async {
    final index = venues.indexWhere((venue) => venue.id == venueId);
    final venue = venues[index];
    venues[index] = Venue(id: venue.id, teamId: venue.teamId, name: venue.name, archived: true);
    return const Right(unit);
  }
}
