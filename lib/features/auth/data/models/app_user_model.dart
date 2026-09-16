import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.id,
    required super.name,
    required super.provider,
    super.avatarUrl,
    super.phone,
    super.username,
  });

  factory AppUserModel.fromEntity(AppUser user) => AppUserModel(
        id: user.id,
        name: user.name,
        provider: user.provider,
        avatarUrl: user.avatarUrl,
        phone: user.phone,
        username: user.username,
      );

  /// Builds the app's user from a Supabase auth [User] plus its optional
  /// `profiles` row (absent until the row is created, e.g. right after
  /// first sign-in). Provider-supplied name/avatar live on the auth user's
  /// metadata; phone/username live only in `profiles`.
  factory AppUserModel.fromSupabase(
    User authUser, {
    Map<String, dynamic>? profileRow,
  }) {
    final metadata = authUser.userMetadata ?? const {};
    final providerName = authUser.appMetadata['provider'] as String?;
    return AppUserModel(
      id: authUser.id,
      name: (profileRow?['name'] as String?) ??
          (metadata['full_name'] ?? metadata['name']) as String? ??
          'Player',
      provider: providerName == 'facebook'
          ? AuthProvider.facebook
          : AuthProvider.google,
      avatarUrl: (profileRow?['avatar_url'] as String?) ??
          (metadata['avatar_url'] ?? metadata['picture']) as String?,
      phone: profileRow?['phone'] as String?,
      username: profileRow?['username'] as String?,
    );
  }
}