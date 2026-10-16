import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/kickoff_forecast.dart';
import '../repositories/forecast_repository.dart';

class KickoffForecastParams extends Equatable {
  const KickoffForecastParams({
    required this.latitude,
    required this.longitude,
    required this.kickoffAt,
  });

  final double latitude;
  final double longitude;
  final DateTime kickoffAt;

  @override
  List<Object?> get props => [latitude, longitude, kickoffAt];
}

class GetKickoffForecast implements UseCase<KickoffForecast, KickoffForecastParams> {
  const GetKickoffForecast(this._repository);

  final ForecastRepository _repository;

  @override
  Future<Either<Failure, KickoffForecast>> call(KickoffForecastParams params) =>
      _repository.getKickoffForecast(params);
}
