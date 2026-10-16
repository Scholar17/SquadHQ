import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// The air measured now at the monitoring station nearest a venue (WAQI,
/// waqi.info). A reading, not a forecast: shown as the air now, any time
/// before kickoff.
class LiveAirQuality extends Equatable {
  const LiveAirQuality({
    required this.usAqi,
    required this.stationName,
    required this.measuredAt,
    required this.distanceKm,
    this.mainPollutant,
    this.pollutantIndexes = const {},
    this.source,
  });

  /// From this US AQI the air is flagged (and the match-day push warns).
  static const alertFrom = 100;

  /// A station further from the venue than this doesn't speak for it.
  static const maxDistanceKm = 25.0;

  /// Stations report hourly, an hour or two late; older than this it's
  /// stale.
  static const maxAge = Duration(hours: 6);

  /// US AQI, 0–500: the worst of the pollutants measured.
  final int usAqi;

  /// E.g. "Chulalongkorn Hospital".
  final String stationName;
  final DateTime measuredAt;
  final double distanceKm;

  /// WAQI's name for the pollutant setting [usAqi]: pm25, pm10, o3 …
  final String? mainPollutant;

  /// Each pollutant's own AQI score — an index like [usAqi], not a
  /// concentration in µg/m³.
  final Map<String, int> pollutantIndexes;

  /// The station network the reading comes from, credited with WAQI.
  final String? source;

  AirQualityLevel get level => AirQualityLevel.fromAqi(usAqi);

  bool get alert => usAqi >= alertFrom;

  /// Worth showing for a match kicking off at [kickoffAt], [now]: until
  /// it kicks off.
  static bool showsFor(DateTime kickoffAt, DateTime now) => kickoffAt.isAfter(now);

  static String pollutantLabel(String key) => switch (key) {
        'pm25' => 'PM2.5',
        'pm10' => 'PM10',
        'o3' => 'ozone',
        'no2' => 'NO₂',
        'so2' => 'SO₂',
        'co' => 'CO',
        _ => key.toUpperCase(),
      };

  /// Kilometres between two points (haversine).
  static double distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    double radians(double degrees) => degrees * math.pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLng = radians(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(lat1)) * math.cos(radians(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  List<Object?> get props =>
      [usAqi, stationName, measuredAt, distanceKm, mainPollutant, pollutantIndexes, source];
}

/// US AQI levels, with what they mean for a match.
enum AirQualityLevel {
  good('Good', 'Good air for playing.'),
  moderate('Moderate', 'Fine for playing.'),
  sensitive(
    'Unhealthy for sensitive groups',
    'Players with asthma or allergies should take it easy; keep the warm-up short.',
  ),
  unhealthy('Unhealthy', 'Consider masks for the warm-up, more breaks, or moving indoors.'),
  veryUnhealthy('Very unhealthy', 'Think about moving the match, or playing indoors.'),
  hazardous('Hazardous', 'Better not to play outdoors.');

  const AirQualityLevel(this.label, this.advice);

  final String label;
  final String advice;

  /// [LiveAirQuality.alertFrom] (100) is already "sensitive" here: the
  /// team warns a step earlier than the official 101.
  static AirQualityLevel fromAqi(int aqi) => switch (aqi) {
        <= 50 => good,
        < LiveAirQuality.alertFrom => moderate,
        <= 150 => sensitive,
        <= 200 => unhealthy,
        <= 300 => veryUnhealthy,
        _ => hazardous,
      };
}
