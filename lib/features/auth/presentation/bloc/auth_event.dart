import 'dart:typed_data';

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
  const AuthOnboardingSubmitted({
    required this.name,
    required this.phone,
    required this.username,
  });

  final String name;
  final String phone;
  final String username;

  @override
  List<Object?> get props => [name, phone, username];
}

/// Edit your profile: any of name, username, phone and photo (null =
/// unchanged).
final class AuthProfileUpdateRequested extends AuthEvent {
  const AuthProfileUpdateRequested({
    this.name,
    this.username,
    this.phone,
    this.avatarBytes,
    this.avatarExtension,
  });

  final String? name;
  final String? username;
  final String? phone;
  final Uint8List? avatarBytes;
  final String? avatarExtension;

  @override
  List<Object?> get props => [name, username, phone, avatarBytes, avatarExtension];
}

/// "Delete account", confirmed.
final class AuthAccountDeletionRequested extends AuthEvent {
  const AuthAccountDeletionRequested();
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

/// Internal — [WatchAuthState]'s stream reported an error, e.g. the OAuth
/// redirect came back with one.
final class AuthStateErrored extends AuthEvent {
  const AuthStateErrored(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The app came back to the foreground — e.g. from the sign-in browser.
final class AuthAppResumed extends AuthEvent {
  const AuthAppResumed();
}

/// Restoring the saved session at start took too long — give up on it and
/// show the login screen rather than the splash forever.
final class AuthRestoreTimedOut extends AuthEvent {
  const AuthRestoreTimedOut();
}
