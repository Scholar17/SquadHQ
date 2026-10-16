import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/weather/domain/entities/kickoff_forecast.dart';
import 'package:squad_hq/features/weather/domain/repositories/forecast_repository.dart';
import 'package:squad_hq/features/weather/domain/usecases/get_kickoff_forecast.dart';

/// The same forecast for any venue and kickoff: 31°C, 40% rain, cloudy.
class FakeForecastRepository implements ForecastRepository {
  KickoffForecast forecast = _cloudy;

  /// What was asked for, newest last.
  final asked = <KickoffForecastParams>[];

  static const _cloudy = KickoffForecast(temperatureC: 31.4, weatherCode: 3, rainChance: 40);

  void reset() {
    forecast = _cloudy;
    asked.clear();
  }

  @override
  Future<Either<Failure, KickoffForecast>> getKickoffForecast(KickoffForecastParams params) async {
    asked.add(params);
    return Right(forecast);
  }
}
