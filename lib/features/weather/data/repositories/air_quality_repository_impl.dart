import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/live_air_quality.dart';
import '../../domain/repositories/air_quality_repository.dart';
import '../../domain/usecases/get_live_air_quality.dart';
import '../datasources/waqi_data_source.dart';

/// Keeps each reading for 30 minutes: stations update hourly, and the hub
/// asks again every half hour while it's open.
class AirQualityRepositoryImpl implements AirQualityRepository {
  AirQualityRepositoryImpl(this._remoteDataSource, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const _keepFor = Duration(minutes: 30);

  final AirQualityRemoteDataSource _remoteDataSource;
  final DateTime Function() _now;
  final _cache = <AirQualityParams, ({DateTime fetchedAt, LiveAirQuality air})>{};

  @override
  Future<Either<Failure, LiveAirQuality>> getLiveAirQuality(AirQualityParams params) async {
    final now = _now();
    final cached = _cache[params];
    final LiveAirQuality air;
    if (cached != null && now.difference(cached.fetchedAt) < _keepFor) {
      air = cached.air;
    } else {
      try {
        air = await _remoteDataSource.getLiveAirQuality(
          latitude: params.latitude,
          longitude: params.longitude,
        );
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } catch (e) {
        return Left(ServerFailure(friendlyErrorMessage(e)));
      }
      _cache[params] = (fetchedAt: now, air: air);
    }
    if (air.distanceKm > LiveAirQuality.maxDistanceKm) {
      return const Left(ValidationFailure('No air quality station near this venue.'));
    }
    if (now.difference(air.measuredAt) > LiveAirQuality.maxAge) {
      return const Left(ValidationFailure("The nearest station hasn't reported lately."));
    }
    return Right(air);
  }
}
