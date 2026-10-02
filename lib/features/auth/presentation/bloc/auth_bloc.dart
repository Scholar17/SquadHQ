import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/complete_onboarding.dart';
import '../../domain/usecases/sign_in_with_facebook.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/watch_auth_state.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required SignInWithFacebook signInWithFacebook,
    required SignInWithGoogle signInWithGoogle,
    required CompleteOnboarding completeOnboarding,
    required SignOut signOut,
    required WatchAuthState watchAuthState,
  })  : _signInWithFacebook = signInWithFacebook,
        _signInWithGoogle = signInWithGoogle,
        _completeOnboarding = completeOnboarding,
        _signOut = signOut,
        super(const AuthInitial()) {
    on<AuthFacebookSignInRequested>(_onFacebookSignIn);
    on<AuthGoogleSignInRequested>(_onGoogleSignIn);
    on<AuthOnboardingSubmitted>(_onOnboardingSubmitted);
    on<AuthSignedOutRequested>(_onSignedOut);
    on<AuthUserChanged>(_onUserChanged);
    _authStateSubscription = watchAuthState().listen(
      (user) => add(AuthUserChanged(user)),
      // E.g. loading the profile failed while offline: keep the current
      // state rather than crash or sign out — the next auth event (or
      // reopening the app) tries again.
      onError: (Object error) {},
    );
  }

  final SignInWithFacebook _signInWithFacebook;
  final SignInWithGoogle _signInWithGoogle;
  final CompleteOnboarding _completeOnboarding;
  final SignOut _signOut;
  late final StreamSubscription<AppUser?> _authStateSubscription;

  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    return super.close();
  }

  Future<void> _onFacebookSignIn(
    AuthFacebookSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final fallback = state;
    emit(AuthLoading(fallback));
    final result = await _signInWithFacebook(const NoParams());
    // Facebook goes through a browser redirect: this call only launches it.
    // On success, stay in AuthLoading — _onUserChanged resolves the real
    // outcome once the redirect completes and the session stream fires.
    result.fold(
      (failure) => emit(AuthFailure(failure.message, fallback)),
      (_) {},
    );
  }

  Future<void> _onGoogleSignIn(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final fallback = state;
    emit(AuthLoading(fallback));
    final result = await _signInWithGoogle(const NoParams());
    // Google goes through a browser redirect, same as Facebook: this call
    // only launches it. On success, stay in AuthLoading — _onUserChanged
    // resolves the real outcome once the redirect completes and the
    // session stream fires.
    result.fold(
      (failure) => emit(AuthFailure(failure.message, fallback)),
      (_) {},
    );
  }

  Future<void> _onOnboardingSubmitted(
    AuthOnboardingSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthNeedsOnboarding) return;
    emit(AuthLoading(current));
    final result = await _completeOnboarding(
      CompleteOnboardingParams(
        userId: current.user.id,
        phone: event.phone,
        username: event.username,
      ),
    );
    result.fold(
      (failure) => emit(AuthFailure(failure.message, current)),
      (user) => emit(AuthAuthenticated(user)),
    );
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

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    final user = event.user;
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
