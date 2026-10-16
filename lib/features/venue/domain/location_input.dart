/// A venue's latitude / longitude as typed or pasted in the venue form.
abstract final class LocationInput {
  static final _number = RegExp(r'^[+-]?\d+(?:\.\d+)?$');
  static final _pair = RegExp(r'^\s*([+-]?\d+(?:\.\d+)?)\s*[,\s]\s*([+-]?\d+(?:\.\d+)?)\s*$');

  /// A pasted "13.7563, 100.5018" (as Google Maps copies it) — both at
  /// once. Null for anything else, or out of range.
  static ({double latitude, double longitude})? pair(String text) {
    final match = _pair.firstMatch(text);
    if (match == null) return null;
    final latitude = double.parse(match.group(1)!);
    final longitude = double.parse(match.group(2)!);
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return (latitude: latitude, longitude: longitude);
  }

  static double? latitude(String text) => _parse(text, 90);

  static double? longitude(String text) => _parse(text, 180);

  static double? _parse(String text, double limit) {
    final trimmed = text.trim();
    if (!_number.hasMatch(trimmed)) return null;
    final value = double.parse(trimmed);
    return value.abs() <= limit ? value : null;
  }

  /// As the form shows it: up to 6 decimals (about 10 cm), no trailing 0s.
  static String format(double value) {
    final text = value.toStringAsFixed(6);
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }
}
