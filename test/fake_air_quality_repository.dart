import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/weather/domain/entities/live_air_quality.dart';
import 'package:squad_hq/features/weather/domain/repositories/air_quality_repository.dart';
import 'package:squad_hq/features/weather/domain/usecases/get_live_air_quality.dart';

/// The same reading near any venue: moderate air, mostly PM2.5, measured
/// an hour ago at Chulalongkorn Hospital.
class FakeAirQualityRepository implements AirQualityRepository {
  late LiveAirQuality air;

  /// Asked for since [reset].
  int asked = 0;

  LiveAirQuality reading({int usAqi = 72, String mainPollutant = 'pm25'}) => LiveAirQuality(
        usAqi: usAqi,
        stationName: 'Chulalongkorn Hospital',
        measuredAt: DateTime.now().subtract(const Duration(hours: 1)),
        distanceKm: 1.4,
        mainPollutant: mainPollutant,
        pollutantIndexes: {'pm25': usAqi, 'pm10': 40},
        source: 'Pollution Control Department',
      );

  void reset() {
    air = reading();
    asked = 0;
  }

  @override
  Future<Either<Failure, LiveAirQuality>> getLiveAirQuality(AirQualityParams params) async {
    asked++;
    return Right(air);
  }
}
