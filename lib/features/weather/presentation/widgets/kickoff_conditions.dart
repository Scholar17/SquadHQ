import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../domain/entities/kickoff_forecast.dart';
import '../../domain/entities/live_air_quality.dart';
import '../../domain/forecast_window.dart';
import '../../domain/usecases/get_kickoff_forecast.dart';
import '../../domain/usecases/get_live_air_quality.dart';
import '../../domain/weather_kind.dart';
import '../temperature_unit_controller.dart';

/// "CONDITIONS" at a venue for a match: the forecast for kickoff and the
/// air measured now — side by side as two tiles, or ([compact]) a row of
/// small chips: temperature, rain, AQI. Each tile shows once it has
/// something to say — weather within 16 days of kickoff ("Forecast from
/// Tue, 4 Nov" before that), air whenever a station near the venue reported
/// lately — and the whole strip is nothing once the match kicks off or
/// neither loads. The air refreshes every half hour.
class KickoffConditions extends StatefulWidget {
  const KickoffConditions({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.kickoffAt,
    this.onDark = false,
    this.title = 'CONDITIONS',
    this.compact = false,
  });

  final double latitude;
  final double longitude;
  final DateTime kickoffAt;

  /// The strip's heading (tiles only).
  final String title;

  /// A row of chips instead of tiles — the Matchday Hub.
  final bool compact;

  /// On the dark hub card rather than a light sheet.
  final bool onDark;

  @override
  State<KickoffConditions> createState() => _KickoffConditionsState();
}

class _KickoffConditionsState extends State<KickoffConditions> {
  static const _refreshAirEvery = Duration(minutes: 30);

  KickoffForecast? _forecast;
  LiveAirQuality? _air;
  Timer? _refreshAir;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshAir = Timer.periodic(_refreshAirEvery, (_) => _loadAir());
  }

  @override
  void didUpdateWidget(KickoffConditions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.kickoffAt != widget.kickoffAt) {
      _forecast = null;
      _air = null;
      _load();
    }
  }

  @override
  void dispose() {
    _refreshAir?.cancel();
    super.dispose();
  }

  bool _isFor(double latitude, double longitude, DateTime kickoffAt) =>
      mounted &&
      latitude == widget.latitude &&
      longitude == widget.longitude &&
      kickoffAt == widget.kickoffAt;

  void _load() {
    _loadForecast();
    _loadAir();
  }

  Future<void> _loadForecast() async {
    final (latitude, longitude, kickoffAt) = (widget.latitude, widget.longitude, widget.kickoffAt);
    if (!ForecastWindow.covers(kickoffAt, DateTime.now())) return;
    final result = await sl<GetKickoffForecast>()(
      KickoffForecastParams(latitude: latitude, longitude: longitude, kickoffAt: kickoffAt),
    );
    if (!_isFor(latitude, longitude, kickoffAt)) return;
    result.fold((_) {}, (forecast) => setState(() => _forecast = forecast));
  }

  Future<void> _loadAir() async {
    final (latitude, longitude, kickoffAt) = (widget.latitude, widget.longitude, widget.kickoffAt);
    if (!LiveAirQuality.showsFor(kickoffAt, DateTime.now())) return;
    final result = await sl<GetLiveAirQuality>()(
      AirQualityParams(latitude: latitude, longitude: longitude),
    );
    if (!_isFor(latitude, longitude, kickoffAt)) return;
    // A stale, far-off or failed reading clears it: never an old number.
    result.fold(
      (_) => setState(() => _air = null),
      (air) => setState(() => _air = air),
    );
  }

  Color get _ink => widget.onDark ? AppColors.onDark : AppColors.text;
  Color get _quiet => widget.onDark ? AppColors.onDarkMuted : AppColors.textMuted;
  Color get _warning => widget.onDark ? AppColors.teamGold : AppColors.categoryGold;
  Color get _alarm => widget.onDark ? AppColors.alertOnDark : AppColors.categoryRose;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!widget.kickoffAt.isAfter(now)) return const SizedBox.shrink();
    if (widget.compact) return _chips(now);
    final weather = _weatherTile(now);
    final air = _air == null ? null : _airTile(_air!);
    if (weather == null && air == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 28, color: _quiet.withValues(alpha: 0.25)),
        Text(
          widget.title,
          style: AppTextStyles.label(color: _quiet).copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (weather != null) Expanded(child: weather),
              if (weather != null && air != null) const SizedBox(width: 10),
              if (air != null) Expanded(child: air),
            ],
          ),
        ),
      ],
    );
  }

  /// Temperature, rain chance and AQI as chips, each tinted when it
  /// matters and explained on a tap; nothing until one has loaded.
  Widget _chips(DateTime now) {
    final forecast = _forecast;
    final air = _air;
    final chips = <Widget>[
      if (!ForecastWindow.covers(widget.kickoffAt, now))
        _chip(
          icon: Icons.cloud_outlined,
          text: 'Forecast from ${_opensOn()}',
          accent: null,
          details: 'The forecast for kickoff comes 16 days before.',
        )
      else if (forecast != null) ...[
        ValueListenableBuilder<TemperatureUnit>(
          valueListenable: sl<TemperatureUnitController>(),
          builder: (context, unit, _) => _chip(
            icon: _icon(forecast),
            text: unit.format(forecast.temperatureC),
            accent: null,
            details: _weatherDetails(forecast, unit),
          ),
        ),
        // A dry day shows just the sky and temperature.
        if (forecast.rainChance case final chance? when forecast.rainWorthShowing)
          _chip(
            icon: Icons.water_drop_outlined,
            text: '$chance%',
            accent: forecast.rainLikely ? _warning : null,
            details: _weatherDetails(forecast, sl<TemperatureUnitController>().value),
          ),
      ],
      if (air != null)
        _chip(
          icon: Icons.air_rounded,
          text: 'AQI ${air.usAqi}',
          accent: _airAccent(air),
          details: _airDetails(air),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _chip({
    required IconData icon,
    required String text,
    required Color? accent,
    required String details,
  }) {
    final color = accent ?? _ink;
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 10),
      message: details,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: accent == null ? 0.08 : 0.16),
          borderRadius: AppRadius.pill,
          border: Border.all(color: color.withValues(alpha: accent == null ? 0.18 : 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              text,
              style: AppTextStyles.body(
                size: 12.5,
                weight: accent == null ? FontWeight.w600 : FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _opensOn() {
    final opens = ForecastWindow.opensOn(widget.kickoffAt);
    return formatMatchDate(DateTime(opens.year, opens.month, opens.day));
  }

  /// Open-Meteo's data is CC BY 4.0: credited wherever it's explained.
  String _weatherDetails(KickoffForecast forecast, TemperatureUnit unit) => [
        'At kickoff: ${unit.format(forecast.temperatureC)}, ${forecast.label.toLowerCase()}'
            '${forecast.rainChance == null ? '' : ', ${forecast.rainChance}% chance of rain'}.',
        if (forecast.rainLikely) 'Rain likely — bring a jacket.',
        'Weather data: Open-Meteo.com.',
      ].join('\n');

  Color? _airAccent(LiveAirQuality air) => switch (air.usAqi) {
        < LiveAirQuality.alertFrom => null,
        <= 150 => _warning,
        _ => _alarm,
      };

  static IconData _icon(KickoffForecast forecast) => switch (forecast.kind) {
        WeatherKind.clear when forecast.isDay => Icons.wb_sunny_outlined,
        WeatherKind.clear => Icons.nightlight_outlined,
        WeatherKind.partlyCloudy when forecast.isDay => Icons.wb_cloudy_outlined,
        WeatherKind.partlyCloudy => Icons.nights_stay_outlined,
        WeatherKind.cloudy => Icons.cloud_outlined,
        WeatherKind.fog => Icons.foggy,
        WeatherKind.drizzle => Icons.grain_rounded,
        WeatherKind.rain => Icons.water_drop_outlined,
        WeatherKind.heavyRain => Icons.umbrella_outlined,
        WeatherKind.snow => Icons.ac_unit_rounded,
        WeatherKind.thunderstorm => Icons.thunderstorm_outlined,
      };

  /// Kickoff's forecast; "Forecast from Tue, 4 Nov" while it's further off than
  /// the forecast reaches; null while it loads (or if it can't).
  Widget? _weatherTile(DateTime now) {
    if (!ForecastWindow.covers(widget.kickoffAt, now)) {
      return _tile(
        accent: null,
        children: [
          Icon(Icons.cloud_outlined, size: 20, color: _quiet),
          const SizedBox(height: 6),
          Text('Forecast', style: AppTextStyles.body(size: 14, weight: FontWeight.w700, color: _ink)),
          Text(
            'from ${_opensOn()}',
            style: AppTextStyles.body(size: 12, color: _quiet),
          ),
        ],
      );
    }
    final forecast = _forecast;
    if (forecast == null) return null;
    final accent = forecast.rainLikely ? _warning : null;
    return ValueListenableBuilder<TemperatureUnit>(
      valueListenable: sl<TemperatureUnitController>(),
      builder: (context, unit, _) => Tooltip(
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 10),
        message: _weatherDetails(forecast, unit),
        child: _tile(
          accent: accent,
          children: [
            Row(
              children: [
                Icon(_icon(forecast), size: 20, color: accent ?? _ink),
                const SizedBox(width: 6),
                Text(
                  unit.format(forecast.temperatureC),
                  style: AppTextStyles.body(size: 18, weight: FontWeight.w800, color: _ink),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (forecast.rainChance case final chance?)
              Text(
                forecast.rainLikely ? '$chance% rain · Rain likely' : '$chance% rain',
                style: AppTextStyles.body(
                  size: 12.5,
                  weight: forecast.rainLikely ? FontWeight.w700 : FontWeight.w600,
                  color: accent ?? _ink,
                ),
              ),
            // The air tile is the latest reading; this one is for kickoff.
            Text(
              '${forecast.label} · at kickoff',
              style: AppTextStyles.body(size: 12, color: _quiet),
            ),
          ],
        ),
      ),
    );
  }

  Widget _airTile(LiveAirQuality air) {
    final accent = _airAccent(air);
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 10),
      message: _airDetails(air),
      child: _tile(
        accent: accent,
        children: [
          Row(
            children: [
              Icon(Icons.air_rounded, size: 20, color: accent ?? _ink),
              const SizedBox(width: 6),
              Text(
                'AQI ${air.usAqi}',
                style: AppTextStyles.body(size: 18, weight: FontWeight.w800, color: accent ?? _ink),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            air.level.label,
            maxLines: 2,
            style: AppTextStyles.body(size: 12.5, weight: FontWeight.w600, color: accent ?? _ink),
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Updated ${formatMatchTime(air.measuredAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(size: 12, color: _quiet),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline_rounded, size: 13, color: _quiet),
            ],
          ),
        ],
      ),
    );
  }

  String _airDetails(LiveAirQuality air) {
    final indexes = [
      for (final MapEntry(:key, :value) in air.pollutantIndexes.entries)
        if (key == 'pm25' || key == 'pm10') '${LiveAirQuality.pollutantLabel(key)} $value',
    ];
    return [
      '${air.level.label} (US AQI ${air.usAqi}). ${air.level.advice}',
      'Measured ${formatMatchTime(air.measuredAt)} at ${air.stationName} station, '
          '${air.distanceKm.toStringAsFixed(1)} km from the venue.',
      if (air.mainPollutant case final main?)
        'Mostly ${LiveAirQuality.pollutantLabel(main)}'
            '${indexes.isEmpty ? '' : ' (indexes: ${indexes.join(', ')})'}.',
      'Air quality data: World Air Quality Index Project (waqi.info)'
          '${air.source == null ? '' : ' and ${air.source}'}.',
    ].join('\n');
  }

  Widget _tile({required Color? accent, required List<Widget> children}) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: (accent ?? _ink).withValues(alpha: accent == null ? 0.06 : 0.12),
          borderRadius: AppRadius.md,
          border: Border.all(color: (accent ?? _ink).withValues(alpha: accent == null ? 0.12 : 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
}
