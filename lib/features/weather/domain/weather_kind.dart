/// What the sky does, grouped from WMO weather codes (the ones Open-Meteo
/// returns) into what a player cares about.
enum WeatherKind {
  clear('Clear'),
  partlyCloudy('Partly cloudy'),
  cloudy('Cloudy'),
  fog('Fog'),
  drizzle('Drizzle'),
  rain('Rain'),
  heavyRain('Heavy rain'),
  snow('Snow'),
  thunderstorm('Thunderstorm');

  const WeatherKind(this.label);

  final String label;

  static WeatherKind fromCode(int code) => switch (code) {
        0 || 1 => clear,
        2 => partlyCloudy,
        3 => cloudy,
        45 || 48 => fog,
        51 || 53 || 55 || 56 || 57 => drizzle,
        61 || 63 || 66 || 80 || 81 => rain,
        65 || 67 || 82 => heavyRain,
        71 || 73 || 75 || 77 || 85 || 86 => snow,
        95 || 96 || 99 => thunderstorm,
        _ => cloudy,
      };
}
