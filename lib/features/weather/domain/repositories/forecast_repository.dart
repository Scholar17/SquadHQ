import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/kickoff_forecast.dart';
import '../usecases/get_kickoff_forecast.dart';

abstract interface class ForecastRepository {
  /// The forecast at a venue for the hour nearest kickoff. Only within
  /// [ForecastWindow](../forecast_window.dart); otherwise a failure.
  Future<Either<Failure, KickoffForecast>> getKickoffForecast(KickoffForecastParams params);
}
