import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Not signed in yet — shows the login screen.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A sign-in or onboarding submission is in flight. [previous] is the
/// settled state to keep showing underneath (e.g. so submitting the
/// onboarding form doesn't flash back to the login screen).
final class AuthLoading extends AuthState {
  const AuthLoading(this.previous);

  final AuthState previous;

  @override
  List<Object?> get props => [previous];
}

/// Signed in via Facebook/Google but hasn't given phone + username yet —
/// shows the "One last thing" onboarding screen.
final class AuthNeedsOnboarding extends AuthState {
  const AuthNeedsOnboarding(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// Fully onboarded — enters the app.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// Sign-in or onboarding failed; [previous] is what to fall back to so the
/// UI knows which screen to show the error on.
final class AuthFailure extends AuthState {
  const AuthFailure(this.message, this.previous);

  final String message;
  final AuthState previous;

  @override
  List<Object?> get props => [message, previous];
}
