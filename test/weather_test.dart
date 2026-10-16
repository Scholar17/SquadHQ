import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:squad_hq/core/error/exceptions.dart';
import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/weather/data/datasources/open_meteo_data_source.dart';
import 'package:squad_hq/features/weather/data/repositories/forecast_repository_impl.dart';
import 'package:squad_hq/features/weather/data/datasources/waqi_data_source.dart';
import 'package:squad_hq/features/weather/data/repositories/air_quality_repository_impl.dart';
import 'package:squad_hq/features/weather/domain/entities/live_air_quality.dart';
import 'package:squad_hq/features/weather/domain/usecases/get_live_air_quality.dart';
import 'package:squad_hq/features/weather/domain/entities/kickoff_forecast.dart';
import 'package:squad_hq/features/weather/domain/forecast_window.dart';
import 'package:squad_hq/features/weather/domain/usecases/get_kickoff_forecast.dart';
import 'package:squad_hq/features/weather/domain/weather_kind.dart';
import 'package:squad_hq/features/weather/presentation/temperature_unit_controller.dart';

void main() {
  group('ForecastWindow', () {
    final now = DateTime.utc(2026, 10, 16, 9);

    test('today and the next 15 days are covered', () {
      expect(ForecastWindow.covers(DateTime.utc(2026, 10, 16, 18), now), isTrue);
      expect(ForecastWindow.covers(DateTime.utc(2026, 10, 31, 23), now), isTrue);
      expect(ForecastWindow.covers(DateTime.utc(2026, 11, 1, 10), now), isFalse);
    });

    test('a match that has kicked off has none', () {
      expect(ForecastWindow.covers(DateTime.utc(2026, 10, 16, 8), now), isFalse);
    });

    test('opens 15 days before the kickoff day', () {
      expect(ForecastWindow.opensOn(DateTime.utc(2026, 11, 20, 12)), DateTime.utc(2026, 11, 5));
    });
  });

  test('weather codes group into what a player cares about', () {
    expect(WeatherKind.fromCode(0), WeatherKind.clear);
    expect(WeatherKind.fromCode(3), WeatherKind.cloudy);
    expect(WeatherKind.fromCode(61), WeatherKind.rain);
    expect(WeatherKind.fromCode(82), WeatherKind.heavyRain);
    expect(WeatherKind.fromCode(95), WeatherKind.thunderstorm);
    expect(WeatherKind.fromCode(1234), WeatherKind.cloudy);
  });

  test('rain is likely from 60%', () {
    expect(const KickoffForecast(temperatureC: 30, weatherCode: 61, rainChance: 59).rainLikely, isFalse);
    expect(const KickoffForecast(temperatureC: 30, weatherCode: 61, rainChance: 60).rainLikely, isTrue);
    expect(const KickoffForecast(temperatureC: 30, weatherCode: 61).rainLikely, isFalse);
  });

  test('temperatures show in °C or °F, whole degrees', () {
    expect(TemperatureUnit.celsius.format(31.4), '31°C');
    expect(TemperatureUnit.fahrenheit.format(31.4), '89°F');
    expect(TemperatureUnit.fahrenheit.format(0), '32°F');
  });

  group('OpenMeteoDataSource', () {
    test('asks for the hour nearest kickoff and reads it', () async {
      late Uri asked;
      final source = OpenMeteoDataSource(
        client: MockClient((request) async {
          asked = request.url;
          return http.Response(
            '{"hourly":{"time":[1792490400],"temperature_2m":[27.7],'
            '"precipitation_probability":[87],"weather_code":[51]}}',
            200,
          );
        }),
      );
      final forecast = await source.getKickoffForecast(
        latitude: 13.7563,
        longitude: 100.5018,
        kickoffAt: DateTime.utc(2026, 10, 20, 9, 45),
      );
      expect(forecast, const KickoffForecast(temperatureC: 27.7, weatherCode: 51, rainChance: 87));
      expect(asked.host, 'api.open-meteo.com');
      expect(asked.queryParameters['start_hour'], '2026-10-20T10:00');
      expect(asked.queryParameters['end_hour'], '2026-10-20T10:00');
      expect(asked.queryParameters['latitude'], '13.7563');
    });

    test('a refused request says why', () async {
      final source = OpenMeteoDataSource(
        client: MockClient(
          (_) async => http.Response('{"error":true,"reason":"out of range"}', 400),
        ),
      );
      expect(
        () => source.getKickoffForecast(latitude: 1, longitude: 1, kickoffAt: DateTime.utc(2026)),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', 'out of range')),
      );
    });
  });

  group('ForecastRepositoryImpl', () {
    final now = DateTime.utc(2026, 10, 16, 9);
    final params = KickoffForecastParams(
      latitude: 13.75,
      longitude: 100.5,
      kickoffAt: DateTime.utc(2026, 10, 18, 11),
    );

    test('keeps a forecast for an hour', () async {
      var calls = 0;
      var clock = now;
      final repository = ForecastRepositoryImpl(
        OpenMeteoDataSource(
          client: MockClient((_) async {
            calls++;
            return http.Response(
              '{"hourly":{"temperature_2m":[30],"precipitation_probability":[10],"weather_code":[0]}}',
              200,
            );
          }),
        ),
        now: () => clock,
      );
      await repository.getKickoffForecast(params);
      await repository.getKickoffForecast(params);
      expect(calls, 1);
      clock = now.add(const Duration(minutes: 61));
      await repository.getKickoffForecast(params);
      expect(calls, 2);
    });

    test("doesn't ask outside the forecast window", () async {
      var calls = 0;
      final repository = ForecastRepositoryImpl(
        OpenMeteoDataSource(
          client: MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        ),
        now: () => now,
      );
      final far = KickoffForecastParams(
        latitude: 13.75,
        longitude: 100.5,
        kickoffAt: DateTime.utc(2026, 12, 1),
      );
      final result = await repository.getKickoffForecast(far);
      expect(result, isA<Left<Failure, KickoffForecast>>());
      expect(calls, 0);
    });
  });

  group('Live air quality', () {
    // As WAQI answered for Polo Football Park on 16 Oct 2026.
    const chulalongkorn = '{"status":"ok","data":{"aqi":75,"dominentpol":"pm25",'
        '"city":{"geo":[13.729852,100.536501],"name":"Chulalongkorn Hospital, Bangkok, Thailand"},'
        '"time":{"s":"2026-10-16 12:00:00","tz":"+07:00","iso":"2026-10-16T12:00:00+07:00"},'
        '"iaqi":{"pm25":{"v":75},"pm10":{"v":56},"o3":{"v":4.8},"t":{"v":33.2}},'
        '"attributions":[{"name":"Division of Air Quality Data, Air Quality and Noise Management Bureau"},'
        '{"name":"World Air Quality Index Project"}]}}';

    WaqiDataSource source(String body, {void Function(Uri)? onAsk}) => WaqiDataSource(
          token: 'test-token',
          client: MockClient((request) async {
            onAsk?.call(request.url);
            return http.Response(body, 200);
          }),
        );

    test('levels follow US AQI, flagged from 100', () {
      expect(AirQualityLevel.fromAqi(40), AirQualityLevel.good);
      expect(AirQualityLevel.fromAqi(99), AirQualityLevel.moderate);
      expect(AirQualityLevel.fromAqi(100), AirQualityLevel.sensitive);
      expect(AirQualityLevel.fromAqi(151), AirQualityLevel.unhealthy);
      expect(AirQualityLevel.fromAqi(250), AirQualityLevel.veryUnhealthy);
      expect(AirQualityLevel.fromAqi(400), AirQualityLevel.hazardous);
    });

    test('shown as the air now, until kickoff', () {
      final now = DateTime.utc(2026, 10, 16, 9);
      expect(LiveAirQuality.showsFor(DateTime.utc(2026, 10, 17, 8), now), isTrue);
      expect(LiveAirQuality.showsFor(DateTime.utc(2026, 10, 30, 10), now), isTrue);
      expect(LiveAirQuality.showsFor(DateTime.utc(2026, 10, 16, 8), now), isFalse);
    });

    test("reads the nearest station's latest reading", () async {
      late Uri asked;
      final air = await source(chulalongkorn, onAsk: (uri) => asked = uri)
          .getLiveAirQuality(latitude: 13.7304, longitude: 100.5505);
      expect(asked.toString(), 'https://api.waqi.info/feed/geo:13.7304;100.5505/?token=test-token');
      expect(air.usAqi, 75);
      expect(air.stationName, 'Chulalongkorn Hospital');
      expect(air.measuredAt, DateTime.utc(2026, 10, 16, 5));
      expect(air.mainPollutant, 'pm25');
      expect(air.pollutantIndexes, {'pm25': 75, 'pm10': 56, 'o3': 5});
      expect(air.source, startsWith('Division of Air Quality Data'));
      expect(air.distanceKm, closeTo(1.5, 0.2));
    });

    test('an offline station ("-") or no token is no reading', () async {
      expect(
        () => source('{"status":"ok","data":{"aqi":"-"}}').getLiveAirQuality(latitude: 1, longitude: 1),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => WaqiDataSource(client: MockClient((_) async => http.Response('', 200)), token: null)
            .getLiveAirQuality(latitude: 1, longitude: 1),
        throwsA(isA<ServerException>()),
      );
    });

    test('a far-off station or an old reading is not shown', () async {
      const yangon = AirQualityParams(latitude: 16.84, longitude: 96.17);
      final far = AirQualityRepositoryImpl(source(chulalongkorn), now: () => DateTime.utc(2026, 10, 16, 6));
      expect(await far.getLiveAirQuality(yangon), isA<Left<Failure, LiveAirQuality>>());

      const polo = AirQualityParams(latitude: 13.7304, longitude: 100.5505);
      final fresh = AirQualityRepositoryImpl(source(chulalongkorn), now: () => DateTime.utc(2026, 10, 16, 6));
      expect(await fresh.getLiveAirQuality(polo), isA<Right<Failure, LiveAirQuality>>());
      final stale = AirQualityRepositoryImpl(source(chulalongkorn), now: () => DateTime.utc(2026, 10, 16, 12));
      expect(await stale.getLiveAirQuality(polo), isA<Left<Failure, LiveAirQuality>>());
    });
  });
}
