import 'package:equatable/equatable.dart';

import '../weather_kind.dart';

/// The weather forecast at a venue for the hour a match kicks off.
class KickoffForecast extends Equatable {
  const KickoffForecast({
    required this.temperatureC,
    required this.weatherCode,
    this.rainChance,
  });

  /// From this chance of rain (%), the forecast warns "Rain likely".
  static const rainLikelyFrom = 60;

  final double temperatureC;

  /// A WMO weather code — see [WeatherKind.fromCode].
  final int weatherCode;

  /// Chance of rain in that hour, 0–100. Null when the forecast has none.
  final int? rainChance;

  bool get rainLikely => (rainChance ?? 0) >= rainLikelyFrom;

  WeatherKind get kind => WeatherKind.fromCode(weatherCode);

  @override
  List<Object?> get props => [temperatureC, weatherCode, rainChance];
}
