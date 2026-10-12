import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The viewer's light / dark choice — System, Light or Dark — kept on
/// this device. The app root listens and repaints with the matching
/// [AppPalette](app_colors.dart).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._(super.value, this._prefs);

  /// Where nothing's been picked yet. Light while the night theme beds in;
  /// switch to [ThemeMode.system] to follow the phone.
  static const fallback = ThemeMode.light;

  static const _key = 'theme_mode';

  final SharedPreferences? _prefs;

  /// Reads the saved choice. Storage can be missing (tests, a locked-down
  /// browser): then it's [fallback], and changes last until restart.
  static Future<ThemeController> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      prefs = null;
    }
    final saved = prefs?.getString(_key);
    final mode = ThemeMode.values.where((mode) => mode.name == saved).firstOrNull;
    return ThemeController._(mode ?? fallback, prefs);
  }

  Future<void> select(ThemeMode mode) async {
    value = mode;
    try {
      await _prefs?.setString(_key, mode.name);
    } catch (_) {
      // Not saved; it still applies for this session.
    }
  }
}
