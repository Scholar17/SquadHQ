/// Compile-time config, supplied via `--dart-define-from-file=.env` (see
/// .env.example for the keys this app expects). Baked into the build output
/// at compile time instead of shipped as a fetchable `assets/.env` file, so
/// it isn't sitting at a public, predictable URL on web.
abstract final class Env {
  static String require(String key) {
    const values = {
      'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
    };
    final value = values[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        '$key is missing. Run with --dart-define-from-file=.env '
        '(see .env.example for the required keys).',
      );
    }
    return value;
  }

  /// Optional keys — null when unset. The Firebase web app config (for web
  /// push) is optional so Android, tests and local web runs work without it.
  static String? optional(String key) {
    const values = {
      'FIREBASE_WEB_API_KEY': String.fromEnvironment('FIREBASE_WEB_API_KEY'),
      'FIREBASE_WEB_APP_ID': String.fromEnvironment('FIREBASE_WEB_APP_ID'),
      'FIREBASE_MESSAGING_SENDER_ID': String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      'FIREBASE_PROJECT_ID': String.fromEnvironment('FIREBASE_PROJECT_ID'),
      'FIREBASE_AUTH_DOMAIN': String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      'FIREBASE_STORAGE_BUCKET': String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      'FIREBASE_WEB_VAPID_KEY': String.fromEnvironment('FIREBASE_WEB_VAPID_KEY'),
    };
    final value = values[key];
    return value == null || value.isEmpty ? null : value;
  }
}
