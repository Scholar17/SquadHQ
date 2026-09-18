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
}