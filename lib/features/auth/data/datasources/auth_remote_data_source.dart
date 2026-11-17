import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show AuthException;

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/validators/onboarding_validators.dart';
import '../models/app_user_model.dart';

/// Postgres' code for a unique index refusing a row — on profiles, a
/// username someone already has (any case, 049_mentions.sql).
const _uniqueViolation = '23505';

abstract interface class AuthRemoteDataSource {
  /// Launches Facebook's browser sign-in; the result arrives later through
  /// [authStateChanges] once the OAuth redirect completes. Facebook has no
  /// reliable native-token path on Android (only iOS's Limited Login yields
  /// the JWT Supabase's `signInWithIdToken` requires), so this goes through
  /// the browser-based OAuth flow instead.
  Future<void> signInWithFacebook();

  /// Launches Google's browser sign-in the same way [signInWithFacebook]
  /// does. The native Credential Manager flow (`google_sign_in` package) was
  /// dropped after it consistently failed with a Play Services-side
  /// "28444: Developer console is not set up correctly" error, reproduced
  /// across two devices and two separate Google Cloud projects with fresh
  /// OAuth clients — pointing to a Play Services bug, not a config issue.
  Future<void> signInWithGoogle();

  Future<AppUserModel> completeOnboarding({
    required String userId,
    required String name,
    required String phone,
    required String username,
  });

  Future<AppUserModel> updateProfile(UpdateProfileParams params);

  Future<void> deleteAccount();

  Future<void> signOut();

  /// Emits the signed-in user (with its `profiles` row merged in) whenever
  /// the Supabase session changes, or `null` when signed out. Supabase
  /// restores a persisted session on [Supabase.initialize], so this also
  /// fires once at app start with whatever session survived the restart —
  /// and it's how a browser OAuth redirect resolves, since the browser
  /// sign-ins return before that completes.
  Stream<AppUserModel?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  /// `squadhq://login-callback` is registered as an intent-filter/URL scheme
  /// on Android/iOS and works there via an OS-level deep link. A browser has
  /// no such mechanism — passing that same custom scheme to Google/Facebook
  /// on web gets the request rejected outright.
  ///
  /// On web this must NOT be left `null`: gotrue omits an absent redirectTo
  /// from the request entirely, so Supabase falls back to the project's
  /// Site URL setting — which is `squadhq://login-callback` here (a holdover
  /// from mobile-only setup), reproducing the exact same broken redirect.
  /// Using the page's own live origin instead means it's always correct
  /// regardless of what Site URL happens to be configured to, and adapts
  /// automatically across dev ports / a future production domain — it just
  /// needs to be listed in Supabase Dashboard → Authentication → URL
  /// Configuration → Redirect URLs (e.g. `http://localhost:<port>` for
  /// local dev).
  static String? get _oauthRedirectUrl =>
      kIsWeb ? Uri.base.origin : 'squadhq://login-callback';

  @override
  Future<void> signInWithFacebook() async {
    try {
      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: _oauthRedirectUrl,
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
      throw AuthException('Facebook sign-in failed: ${friendlyErrorMessage(e)}');
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _oauthRedirectUrl,
        authScreenLaunchMode: LaunchMode.inAppBrowserView,
        // Without this, Google silently reuses whichever account is
        // already signed into the device's browser instead of letting the
        // user pick, since the OAuth request otherwise looks like a normal
        // SSO continuation.
        queryParams: const {'prompt': 'select_account'},
      );
      if (!launched) {
        throw const AuthException('Could not open Google sign-in.');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Google sign-in failed: ${friendlyErrorMessage(e)}');
    }
  }

  @override
  Future<AppUserModel> completeOnboarding({
    required String userId,
    required String name,
    required String phone,
    required String username,
  }) async {
    try {
      final row = await _supabase
          .from('profiles')
          .update({'name': name, 'phone': phone, 'username': username})
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
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) throw const ServerException(OnboardingValidators.usernameTaken);
      throw ServerException('Could not save your details: $e');
    } catch (e) {
      throw ServerException('Could not save your details: $e');
    }
  }

  @override
  Future<AppUserModel> updateProfile(UpdateProfileParams params) async {
    try {
      final changes = <String, Object?>{
        if (params.name case final name?) 'name': name.trim(),
        if (params.username case final username?) 'username': username.trim(),
        'phone': ?params.phone,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      // A new photo: into the public avatars bucket (038), its link on the
      // profile. A fresh file each time, so caches never show the old one.
      if (params.avatarBytes case final bytes?) {
        final extension = params.avatarExtension ?? 'jpg';
        final path = '${params.userId}/${DateTime.now().millisecondsSinceEpoch}.$extension';
        final bucket = _supabase.storage.from('avatars');
        await bucket.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
        changes['avatar_url'] = bucket.getPublicUrl(path);
      }
      final row = await _supabase
          .from('profiles')
          .update(changes)
          .eq('id', params.userId)
          .select()
          .single();
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw const ServerException('You were signed out.');
      return AppUserModel.fromSupabase(authUser, profileRow: row);
    } on ServerException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) throw const ServerException(OnboardingValidators.usernameTaken);
      throw ServerException('Could not save your profile: ${friendlyErrorMessage(e)}');
    } on StorageException catch (e) {
      throw ServerException('Could not upload your photo: ${e.message}');
    } catch (e) {
      throw ServerException('Could not save your profile: ${friendlyErrorMessage(e)}');
    }
  }

  @override
  Future<void> deleteAccount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const ServerException('You were signed out.');
    // Your own image files first — best effort: a leftover file is
    // unreachable once its link is gone from the profile.
    try {
      final row = await _supabase
          .from('profiles')
          .select('wallet_qr_path')
          .eq('id', userId)
          .maybeSingle();
      if (row?['wallet_qr_path'] case final String qr) {
        await _supabase.storage.from('wallet-qr').remove([qr]);
      }
      final avatars = _supabase.storage.from('avatars');
      final files = await avatars.list(path: userId);
      if (files.isNotEmpty) {
        await avatars.remove([for (final f in files) '$userId/${f.name}']);
      }
    } catch (_) {
      // Not worth stopping the deletion for.
    }
    try {
      await _supabase.rpc('delete_my_account');
    } on PostgrestException catch (e) {
      throw ServerException('Could not delete your account: ${e.message}');
    }
    // The login no longer exists; drop the session on this device.
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed: ${friendlyErrorMessage(e)}');
    }
  }

  @override
  Stream<AppUserModel?> get authStateChanges =>
      _supabase.auth.onAuthStateChange
          // A failed background session refresh (phone offline or asleep)
          // arrives here as AuthRetryableFetchException. Supabase retries on
          // its own, so it isn't worth surfacing — the user stays signed in.
          .handleError((_) {}, test: (error) => isNetworkError(error as Object))
          // An OAuth redirect that came back with an error (e.g. the
          // Facebook app is misconfigured) arrives here too — as our own
          // AuthException, so the sign-in screen can show its message.
          .transform(
            StreamTransformer<AuthState, AuthState>.fromHandlers(
              handleError: (error, stackTrace, sink) => sink.addError(
                error is supabase.AuthException
                    ? AuthException('Sign-in failed: ${error.message}')
                    : error,
                stackTrace,
              ),
            ),
          )
          .asyncMap((data) async {
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
