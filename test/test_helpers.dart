import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps [Supabase.initialize] off `SharedPreferences`, which isn't
/// available in the widget-test environment.
class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _store[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);
}

/// Initializes Supabase with a dummy project and in-memory storage so
/// widget tests can build [AuthBloc] (which watches `auth.onAuthStateChange`)
/// without a real project or platform plugins.
Future<void> initTestSupabase() => Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAsyncStorage(),
      ),
    );