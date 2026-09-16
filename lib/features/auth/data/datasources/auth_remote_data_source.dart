import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/error/exceptions.dart';
import '../models/app_user_model.dart';

abstract interface class AuthRemoteDataSource {
  /// Launches Facebook's browser sign-in; the result arrives later through
  /// [authStateChanges] once the OAuth redirect completes. Facebook has no
  /// reliable native-token path on Android (only iOS's Limited Login yields
  /// the JWT Supabase's `signInWithIdToken` requires), so this goes through
  /// the browser-based OAuth flow instead.
  Future<void> signInWithFacebook();

  Future<AppUserModel> signInWithGoogle();

  Future<AppUserModel> completeOnboarding({
    required String userId,
    required String phone,
    required String username,
  });

  Future<void> signOut();

  /// Emits the signed-in user (with its `profiles` row merged in) whenever
  /// the Supabase session changes, or `null` when signed out. Supabase
  /// restores a persisted session on [Supabase.initialize], so this also
  /// fires once at app start with whatever session survived the restart —
  /// and it's how a Facebook OAuth redirect resolves, since
  /// [signInWithFacebook] returns before that completes.
  Stream<AppUserModel?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
    required String googleWebClientId,
    required String googleIosClientId,
    GoogleSignIn? googleSignIn,
  })  : _supabase = supabaseClient,
        _webClientId = googleWebClientId,
        _iosClientId = googleIosClientId,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;
  final String _webClientId;
  final String _iosClientId;

  /// Registered as a redirect URL in the Supabase dashboard and as an
  /// intent-filter/URL scheme on Android/iOS.
  static const _facebookRedirectUrl = 'squadhq://login-callback';

  @override
  Future<void> signInWithFacebook() async {
    try {
      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: _facebookRedirectUrl,
        // Without this, Android's App Links hands facebook.com straight to
        // the installed Facebook app instead of a browser (no chooser),
        // which isn't the OAuth flow we've configured.
        authScreenLaunchMode: LaunchMode.inAppBrowserView,
      );
      if (!launched) {
        throw const AuthException('Could not open Facebook sign-in.');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Facebook sign-in failed: $e');
    }
  }

  @override
  Future<AppUserModel> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: _webClientId,
        clientId: _iosClientId,
      );
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException('Google sign-in did not return an ID token.');
      }
      final authorization = await account.authorizationClient
              .authorizationForScopes(const ['email', 'profile']) ??
          await account.authorizationClient
              .authorizeScopes(const ['email', 'profile']);
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
      return await _loadOrCreateProfile(response.user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Google sign-in was cancelled.');
      }
      throw AuthException('Google sign-in failed: ${e.description ?? e.code}');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Google sign-in failed: $e');
    }
  }

  @override
  Future<AppUserModel> completeOnboarding({
    required String userId,
    required String phone,
    required String username,
  }) async {
    try {
      final row = await _supabase
          .from('profiles')
          .update({'phone': phone, 'username': username})
          .eq('id', userId)
          .select()
          .single();
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        throw const ServerException('No signed-in user to onboard.');
      }
      return AppUserModel.fromSupabase(authUser, profileRow: row);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Could not save your details: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([
        _supabase.auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw AuthException('Sign out failed: $e');
    }
  }

  @override
  Stream<AppUserModel?> get authStateChanges =>
      _supabase.auth.onAuthStateChange.asyncMap((data) async {
        final authUser = data.session?.user;
        if (authUser == null) return null;
        return _loadOrCreateProfile(authUser);
      });

  Future<AppUserModel> _loadOrCreateProfile(User? authUser) async {
    if (authUser == null) {
      throw const AuthException('Sign-in did not return a user.');
    }
    final existing = await _fetchProfile(authUser.id);
    if (existing != null) {
      return AppUserModel.fromSupabase(authUser, profileRow: existing);
    }
    final draft = AppUserModel.fromSupabase(authUser);
    final created = await _supabase
        .from('profiles')
        .insert({
          'id': authUser.id,
          'provider': draft.provider.name,
          'name': draft.name,
          'avatar_url': draft.avatarUrl,
        })
        .select()
        .single();
    return AppUserModel.fromSupabase(authUser, profileRow: created);
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) {
    return _supabase.from('profiles').select().eq('id', userId).maybeSingle();
  }
}
