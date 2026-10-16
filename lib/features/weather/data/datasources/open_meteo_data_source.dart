import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/kickoff_forecast.dart';

abstract interface class ForecastRemoteDataSource {
  Future<KickoffForecast> getKickoffForecast({
    required double latitude,
    required double longitude,
    required DateTime kickoffAt,
  });
}

/// Open-Meteo's free forecast API (open-meteo.com): no key, called straight
/// from the app. Asks for the one hour nearest kickoff, in UTC.
class OpenMeteoDataSource implements ForecastRemoteDataSource {
  OpenMeteoDataSource({required http.Client client}) : _client = client;

  final http.Client _client;

  static String _hour(DateTime time) {
    final utc = time.toUtc();
    final rounded = DateTime.utc(utc.year, utc.month, utc.day, utc.hour)
        .add(Duration(hours: utc.minute >= 30 ? 1 : 0));
    return rounded.toIso8601String().substring(0, 13); // 2026-10-20T10
  }

  /// [variables] for the kickoff hour, each its one value (or null).
  Future<Map<String, num?>> _kickoffHour({
    required String host,
    required String path,
    required List<String> variables,
    required double latitude,
    required double longitude,
    required DateTime kickoffAt,
  }) async {
    final hour = '${_hour(kickoffAt)}:00';
    final uri = Uri.https(host, path, {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'hourly': variables.join(','),
      'timeformat': 'unixtime',
      'start_hour': hour,
      'end_hour': hour,
    });
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const ServerException("Couldn't load the forecast.");
    }
    Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      body = null;
    }
    if (response.statusCode != 200 || body is! Map<String, dynamic>) {
      throw ServerException(
        body is Map<String, dynamic> && body['reason'] is String
            ? body['reason'] as String
            : "Couldn't load the forecast.",
      );
    }
    final hourly = body['hourly'] as Map<String, dynamic>?;
    return {
      for (final variable in variables)
        variable: switch (hourly?[variable]) {
          [final num value, ...] => value,
          _ => null,
        },
    };
  }

  @override
  Future<KickoffForecast> getKickoffForecast({
    required double latitude,
    required double longitude,
    required DateTime kickoffAt,
  }) async {
    final values = await _kickoffHour(
      host: 'api.open-meteo.com',
      path: '/v1/forecast',
      variables: const ['temperature_2m', 'precipitation_probability', 'weather_code'],
      latitude: latitude,
      longitude: longitude,
      kickoffAt: kickoffAt,
    );
    final temperature = values['temperature_2m'];
    final code = values['weather_code'];
    if (temperature == null || code == null) {
      throw const ServerException('No forecast for that time.');
    }
    return KickoffForecast(
      temperatureC: temperature.toDouble(),
      weatherCode: code.toInt(),
      rainChance: values['precipitation_probability']?.toInt(),
    );
  }
}
