import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TemperatureUnit {
  celsius('°C'),
  fahrenheit('°F');

  const TemperatureUnit(this.symbol);

  final String symbol;

  /// E.g. "31°C" or "88°F", rounded to a whole degree.
  String format(double celsius) {
    final value = this == fahrenheit ? celsius * 9 / 5 + 32 : celsius;
    return '${value.round()}$symbol';
  }
}

/// The viewer's °C / °F choice for forecasts, kept on this device. °C
/// until they pick.
class TemperatureUnitController extends ValueNotifier<TemperatureUnit> {
  TemperatureUnitController._(super.value, this._prefs);

  static const _key = 'temperature_unit';

  final SharedPreferences? _prefs;

  /// Reads the saved choice. Storage can be missing (tests, a locked-down
  /// browser): then it's °C, and changes last until restart.
  static Future<TemperatureUnitController> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      prefs = null;
    }
    final saved = prefs?.getString(_key);
    final unit = TemperatureUnit.values.where((unit) => unit.name == saved).firstOrNull;
    return TemperatureUnitController._(unit ?? TemperatureUnit.celsius, prefs);
  }

  Future<void> select(TemperatureUnit unit) async {
    value = unit;
    try {
      await _prefs?.setString(_key, unit.name);
    } catch (_) {
      // Not saved; it still applies for this session.
    }
  }
}
