import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/kickoff_forecast.dart';
import '../../domain/forecast_window.dart';
import '../../domain/repositories/forecast_repository.dart';
import '../../domain/usecases/get_kickoff_forecast.dart';
import '../datasources/open_meteo_data_source.dart';

/// Keeps each forecast for an hour, so moving between tabs and sheets
/// doesn't fetch it again.
class ForecastRepositoryImpl implements ForecastRepository {
  ForecastRepositoryImpl(this._remoteDataSource, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const _keepFor = Duration(hours: 1);

  final ForecastRemoteDataSource _remoteDataSource;
  final DateTime Function() _now;
  final _cache = <KickoffForecastParams, ({DateTime fetchedAt, KickoffForecast forecast})>{};

  @override
  Future<Either<Failure, KickoffForecast>> getKickoffForecast(KickoffForecastParams params) async {
    final now = _now();
    if (!ForecastWindow.covers(params.kickoffAt, now)) {
      return const Left(ValidationFailure('No forecast for that day yet.'));
    }
    final cached = _cache[params];
    if (cached != null && now.difference(cached.fetchedAt) < _keepFor) {
      return Right(cached.forecast);
    }
    try {
      final forecast = await _remoteDataSource.getKickoffForecast(
        latitude: params.latitude,
        longitude: params.longitude,
        kickoffAt: params.kickoffAt,
      );
      _cache[params] = (fetchedAt: now, forecast: forecast);
      return Right(forecast);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }
}
