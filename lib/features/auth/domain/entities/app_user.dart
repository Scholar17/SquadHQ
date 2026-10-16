import 'package:equatable/equatable.dart';

enum AuthProvider { facebook, google }

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.provider,
    this.avatarUrl,
    this.phone,
    this.username,
    this.email,
  });

  final String id;
  final String name;
  final AuthProvider provider;
  final String? avatarUrl;
  final String? phone;
  final String? username;

  /// The Google/Facebook account's email they sign in with; null when the
  /// provider doesn't share one (Facebook accounts made with a phone).
  final String? email;

  /// The design's onboarding step ("One last thing") collects phone +
  /// username right after social sign-in; until both exist the user is
  /// mid-onboarding.
  bool get hasCompletedOnboarding => phone != null && username != null;

  AppUser copyWith({String? phone, String? username}) => AppUser(
        id: id,
        name: name,
        provider: provider,
        avatarUrl: avatarUrl,
        phone: phone ?? this.phone,
        username: username ?? this.username,
        email: email,
      );

  @override
  List<Object?> get props => [id, name, provider, avatarUrl, phone, username, email];
}
