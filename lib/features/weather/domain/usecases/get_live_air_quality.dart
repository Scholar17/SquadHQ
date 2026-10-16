import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/live_air_quality.dart';
import '../repositories/air_quality_repository.dart';

class AirQualityParams extends Equatable {
  const AirQualityParams({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [latitude, longitude];
}

class GetLiveAirQuality implements UseCase<LiveAirQuality, AirQualityParams> {
  const GetLiveAirQuality(this._repository);

  final AirQualityRepository _repository;

  @override
  Future<Either<Failure, LiveAirQuality>> call(AirQualityParams params) =>
      _repository.getLiveAirQuality(params);
}
