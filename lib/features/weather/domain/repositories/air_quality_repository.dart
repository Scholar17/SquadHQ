import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/live_air_quality.dart';
import '../usecases/get_live_air_quality.dart';

abstract interface class AirQualityRepository {
  /// The latest reading at the station nearest the venue. A failure when
  /// there's none within [LiveAirQuality.maxDistanceKm], or it's older
  /// than [LiveAirQuality.maxAge].
  Future<Either<Failure, LiveAirQuality>> getLiveAirQuality(AirQualityParams params);
}
