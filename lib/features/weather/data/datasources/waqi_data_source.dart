import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/live_air_quality.dart';

abstract interface class AirQualityRemoteDataSource {
  Future<LiveAirQuality> getLiveAirQuality({required double latitude, required double longitude});
}

/// The World Air Quality Index project's feed (waqi.info): the latest
/// reading at the station nearest a point, from government monitors
/// (e.g. Thailand's Pollution Control Department). Free, non-commercial,
/// with a token ([token] null: no air quality at all).
class WaqiDataSource implements AirQualityRemoteDataSource {
  WaqiDataSource({required http.Client client, required String? token})
      : _client = client,
        _token = token;

  final http.Client _client;
  final String? _token;

  static const _pollutants = ['pm25', 'pm10', 'o3', 'no2', 'so2', 'co'];

  @override
  Future<LiveAirQuality> getLiveAirQuality({
    required double latitude,
    required double longitude,
  }) async {
    final token = _token;
    if (token == null) throw const ServerException('Live air quality is not set up.');
    final point = '${latitude.toStringAsFixed(4)};${longitude.toStringAsFixed(4)}';
    final uri = Uri.https('api.waqi.info', '/feed/geo:$point/', {'token': token});
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const ServerException("Couldn't load the air quality.");
    }
    Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      body = null;
    }
    if (body case {'status': 'ok', 'data': final Map<String, dynamic> data}) {
      return _reading(data, latitude, longitude);
    }
    throw const ServerException("Couldn't load the air quality.");
  }

  LiveAirQuality _reading(Map<String, dynamic> data, double latitude, double longitude) {
    // A station that's offline reports "-".
    final aqi = data['aqi'];
    final measuredAt = switch (data['time']) {
      {'iso': final String iso} => DateTime.tryParse(iso),
      _ => null,
    };
    final (name, geo) = switch (data['city']) {
      {'name': final String name, 'geo': [final num lat, final num lng, ...]} => (
          name,
          (lat.toDouble(), lng.toDouble()),
        ),
      _ => (null, null),
    };
    if (aqi is! num || measuredAt == null || name == null || geo == null) {
      throw const ServerException('No reading from the nearest station.');
    }
    final iaqi = data['iaqi'];
    final attributions = data['attributions'];
    return LiveAirQuality(
      usAqi: aqi.round(),
      // "Chulalongkorn Hospital, Bangkok, Thailand (…)" → its first part.
      stationName: name.split(',').first.trim(),
      measuredAt: measuredAt,
      distanceKm: LiveAirQuality.distanceBetween(latitude, longitude, geo.$1, geo.$2),
      mainPollutant: data['dominentpol'] as String?, // sic: WAQI's spelling
      pollutantIndexes: {
        if (iaqi is Map)
          for (final key in _pollutants)
            if (iaqi[key] case {'v': final num value}) key: value.round(),
      },
      source: attributions is List
          ? attributions
              .whereType<Map>()
              .map((attribution) => attribution['name'])
              .whereType<String>()
              .where((name) => !name.contains('World Air Quality Index'))
              .firstOrNull
          : null,
    );
  }
}
