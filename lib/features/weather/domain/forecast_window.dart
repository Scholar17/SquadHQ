/// How far ahead a kickoff forecast exists: Open-Meteo forecasts today
/// plus the next 15 days (UTC).
abstract final class ForecastWindow {
  static const days = 16;

  /// The first day (UTC) [kickoffAt]'s forecast can be fetched.
  static DateTime opensOn(DateTime kickoffAt, {int days = ForecastWindow.days}) {
    final kickoff = kickoffAt.toUtc();
    return DateTime.utc(kickoff.year, kickoff.month, kickoff.day)
        .subtract(Duration(days: days - 1));
  }

  /// A forecast for [kickoffAt] can be fetched [now]: it hasn't kicked
  /// off and it's within [days].
  static bool covers(DateTime kickoffAt, DateTime now, {int days = ForecastWindow.days}) {
    if (!kickoffAt.isAfter(now)) return false;
    final today = now.toUtc();
    return !DateTime.utc(today.year, today.month, today.day)
        .isBefore(opensOn(kickoffAt, days: days));
  }
}
