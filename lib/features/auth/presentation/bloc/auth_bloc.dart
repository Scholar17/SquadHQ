import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/complete_onboarding.dart';
import '../../domain/usecases/delete_account.dart';
import '../../domain/usecases/sign_in_with_facebook.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/usecases/watch_auth_state.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this._signInWithFacebook,
    required this._signInWithGoogle,
    required this._completeOnboarding,
    required this._signOut,
    required WatchAuthState watchAuthState,
    required this._updateProfile,
    required this._deleteAccount,
  })  : super(const AuthRestoring()) {
    on<AuthFacebookSignInRequested>(_onFacebookSignIn);
    on<AuthGoogleSignInRequested>(_onGoogleSignIn);
    on<AuthOnboardingSubmitted>(_onOnboardingSubmitted);
    on<AuthSignedOutRequested>(_onSignedOut);
    on<AuthProfileUpdateRequested>(_onProfileUpdateRequested);
    on<AuthAccountDeletionRequested>(_onAccountDeletionRequested);
    on<AuthUserChanged>(_onUserChanged);
    on<AuthStateErrored>(_onStateErrored);
    on<AuthAppResumed>(_onAppResumed);
    on<AuthRestoreTimedOut>(_onRestoreTimedOut);
    _restoreTimeout = Timer(_restoreGrace, () => add(const AuthRestoreTimedOut()));
    _authStateSubscription = watchAuthState().listen(
      (user) => add(AuthUserChanged(user)),
      // E.g. the OAuth redirect came back with an error, or loading the
      // profile failed: shown if a sign-in is waiting on it, otherwise the
      // current state is kept — the next auth event (or reopening the app)
      // tries again.
      onError: (Object error) => add(
        AuthStateErrored(
          error is AuthException ? error.message : friendlyErrorMessage(error),
        ),
      ),
    );
  }

  final SignInWithFacebook _signInWithFacebook;
  final SignInWithGoogle _signInWithGoogle;
  final CompleteOnboarding _completeOnboarding;
  final SignOut _signOut;
  final UpdateProfile _updateProfile;
  final DeleteAccount _deleteAccount;
  late final StreamSubscription<AppUser?> _authStateSubscription;
  late final Timer _restoreTimeout;

  /// The session (and its profile) normally restores in well under a
  /// second; this only catches it never arriving.
  static const _restoreGrace = Duration(seconds: 10);

  /// A Facebook/Google sign-in was launched and its session hasn't arrived
  /// yet — the login screen shows AuthLoading meanwhile.
  bool _awaitingRedirect = false;

  /// How long after returning from the browser to wait for the redirect's
  /// session before deciding the sign-in was abandoned.
  static const _redirectGrace = Duration(seconds: 5);

  @override
  Future<void> close() {
    _restoreTimeout.cancel();
    _authStateSubscription.cancel();
    return super.close();
  }

  Future<void> _onFacebookSignIn(
    AuthFacebookSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final fallback = state;
    emit(AuthLoading(fallback));
    // Not flagged as awaiting a redirect until this returns: on mobile it's
    // the native SDK, so coming back from the Facebook app mid-sign-in
    // mustn't start the abandoned-browser timeout.
    final result = await _signInWithFacebook(const NoParams());
    // On success, stay in AuthLoading — _onUserChanged resolves the real
    // outcome once the session stream fires (and its profile loads).
    result.fold(
      (failure) => emit(AuthFailure(failure.message, fallback)),
      (_) => _awaitingRedirect = true,
    );
  }

  Future<void> _onGoogleSignIn(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final fallback = state;
    emit(AuthLoading(fallback));
    _awaitingRedirect = true;
    final result = await _signInWithGoogle(const NoParams());
    // Google goes through a browser redirect (Facebook does on web): this call
    // only launches it. On success, stay in AuthLoading — _onUserChanged
    // resolves the real outcome once the redirect completes and the
    // session stream fires.
    result.fold(
      (failure) {
        _awaitingRedirect = false;
        emit(AuthFailure(failure.message, fallback));
      },
      (_) {},
    );
  }

  /// Where things stand, looking past a failed save — so after an error
  /// (e.g. a taken mention name) the next try goes through instead of
  /// being ignored.
  AuthState get _settled => switch (state) {
        AuthFailure(:final previous) => previous,
        final state => state,
      };

  Future<void> _onOnboardingSubmitted(
    AuthOnboardingSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final current = _settled;
    if (current is! AuthNeedsOnboarding) return;
    emit(AuthLoading(current));
    final result = await _completeOnboarding(
      CompleteOnboardingParams(
        userId: current.user.id,
        name: event.name,
        phone: event.phone,
        username: event.username,
      ),
    );
    result.fold(
      (failure) => emit(AuthFailure(failure.message, current)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// Saves your edits; the router keeps you where you are while it loads
  /// (it reads through AuthLoading), and every screen picks up the result.
  Future<void> _onProfileUpdateRequested(
    AuthProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = _settled;
    if (current is! AuthAuthenticated) return;
    emit(AuthLoading(current));
    final result = await _updateProfile(
      UpdateProfileParams(
        userId: current.user.id,
        name: event.name,
        username: event.username,
        phone: event.phone,
        avatarBytes: event.avatarBytes,
        avatarExtension: event.avatarExtension,
      ),
    );
    result.fold(
      (failure) => emit(AuthFailure(failure.message, current)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  /// Deletes the account; on success the sign-out that follows arrives as
  /// a null user (AuthUserChanged), which takes the app to the login page.
  Future<void> _onAccountDeletionRequested(
    AuthAccountDeletionRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = _settled;
    if (current is! AuthAuthenticated) return;
    emit(AuthLoading(current));
    final result = await _deleteAccount(const NoParams());
    result.fold((failure) => emit(AuthFailure(failure.message, current)), (_) {});
  }

  Future<void> _onSignedOut(
    AuthSignedOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final fallback = state;
    emit(AuthLoading(fallback));
    final result = await _signOut(const NoParams());
    result.fold(
      (failure) => emit(AuthFailure(failure.message, fallback)),
      (_) => emit(const AuthInitial()),
    );
  }

  void _onStateErrored(AuthStateErrored event, Emitter<AuthState> emit) {
    final current = state;
    // The saved session couldn't be restored (e.g. its profile didn't
    // load): to the login screen, saying why, rather than a stuck splash.
    if (current is AuthRestoring) {
      _restoreTimeout.cancel();
      emit(AuthFailure(event.message, const AuthInitial()));
      return;
    }
    if (!_awaitingRedirect || current is! AuthLoading) return;
    _awaitingRedirect = false;
    emit(AuthFailure(event.message, current.previous));
  }

  /// Back from the browser: if no session (or error) arrives shortly, the
  /// sign-in was closed or cancelled — drop the spinner. A redirect that
  /// lands later still signs you in through [_onUserChanged].
  Future<void> _onAppResumed(AuthAppResumed event, Emitter<AuthState> emit) async {
    if (!_awaitingRedirect) return;
    await Future<void>.delayed(_redirectGrace);
    final current = state;
    if (!_awaitingRedirect || current is! AuthLoading) return;
    _awaitingRedirect = false;
    emit(current.previous);
  }

  void _onRestoreTimedOut(AuthRestoreTimedOut event, Emitter<AuthState> emit) {
    if (state is AuthRestoring) emit(const AuthInitial());
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    _restoreTimeout.cancel();
    final user = event.user;
    if (user != null) _awaitingRedirect = false;
    if (user == null) {
      // Bloc's own equality dedup only applies from the second emit
      // onward, so guard explicitly: the stream's first event, right
      // after construction, fires even when it just confirms the
      // already-current "signed out" state — that's not a real sign-out
      // and must not trigger listeners built to react to one (e.g. the
      // profile screen popping itself on session loss).
      if (state is! AuthInitial) emit(const AuthInitial());
    } else {
      emit(
        user.hasCompletedOnboarding
            ? AuthAuthenticated(user)
            : AuthNeedsOnboarding(user),
      );
    }
  }
}
