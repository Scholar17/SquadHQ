import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthFacebookSignInRequested extends AuthEvent {
  const AuthFacebookSignInRequested();
}

final class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

final class AuthOnboardingSubmitted extends AuthEvent {
  const AuthOnboardingSubmitted({required this.phone, required this.username});

  final String phone;
  final String username;

  @override
  List<Object?> get props => [phone, username];
}

final class AuthSignedOutRequested extends AuthEvent {
  const AuthSignedOutRequested();
}

/// Internal — fired whenever [WatchAuthState]'s stream emits (sign-in,
/// sign-out, or a session restored at app start).
final class AuthUserChanged extends AuthEvent {
  const AuthUserChanged(this.user);

  final AppUser? user;

  @override
  List<Object?> get props => [user];
}
