import 'package:equatable/equatable.dart';

import '../weather_kind.dart';

/// The weather forecast at a venue for the hour a match kicks off.
class KickoffForecast extends Equatable {
  const KickoffForecast({
    required this.temperatureC,
    required this.weatherCode,
    this.rainChance,
    this.isDay = true,
  });

  /// Below this chance of rain (%), the hub leaves it out: a dry day shows
  /// just the sky and temperature.
  static const rainShownFrom = 30;

  /// From this chance of rain (%), the forecast warns "Rain likely".
  static const rainLikelyFrom = 60;

  final double temperatureC;

  /// A WMO weather code — see [WeatherKind.fromCode].
  final int weatherCode;

  /// Chance of rain in that hour, 0–100. Null when the forecast has none.
  final int? rainChance;

  /// Kickoff is in daylight: a clear sky is "Sunny" with a sun, or "Clear"
  /// with a moon after dark.
  final bool isDay;

  bool get rainLikely => (rainChance ?? 0) >= rainLikelyFrom;

  bool get rainWorthShowing => (rainChance ?? 0) >= rainShownFrom;

  /// "Sunny" by day; [WeatherKind.label] otherwise.
  String get label => kind == WeatherKind.clear && isDay ? 'Sunny' : kind.label;

  WeatherKind get kind => WeatherKind.fromCode(weatherCode);

  @override
  List<Object?> get props => [temperatureC, weatherCode, rainChance, isDay];
}
