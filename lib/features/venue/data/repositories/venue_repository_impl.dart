import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/venue.dart';
import '../../domain/repositories/venue_repository.dart';
import '../../domain/usecases/save_venue.dart';
import '../datasources/venue_remote_data_source.dart';

class VenueRepositoryImpl implements VenueRepository {
  const VenueRepositoryImpl(this._remoteDataSource);

  final VenueRemoteDataSource _remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, List<Venue>>> getTeamVenues(String teamId) =>
      _guard(() => _remoteDataSource.getTeamVenues(teamId));

  @override
  Future<Either<Failure, Venue>> getVenue(String venueId) =>
      _guard(() => _remoteDataSource.getVenue(venueId));

  @override
  Future<Either<Failure, Venue>> saveVenue(SaveVenueParams params) =>
      _guard(() => _remoteDataSource.saveVenue(params));

  @override
  Future<Either<Failure, Unit>> archiveVenue(String venueId) => _guard(() async {
        await _remoteDataSource.archiveVenue(venueId);
        return unit;
      });
}
