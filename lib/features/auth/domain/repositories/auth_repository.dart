import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';
import '../usecases/update_profile.dart';

abstract interface class AuthRepository {
  /// Launches Facebook's browser sign-in; success/failure of the sign-in
  /// itself arrives later via [authStateChanges], not this call's result.
  Future<Either<Failure, Unit>> signInWithFacebook();

  /// Launches Google's browser sign-in; success/failure of the sign-in
  /// itself arrives later via [authStateChanges], not this call's result.
  Future<Either<Failure, Unit>> signInWithGoogle();

  Future<Either<Failure, AppUser>> completeOnboarding({
    required String userId,
    required String name,
    required String phone,
    required String username,
  });

  /// Saves your name, phone and/or profile photo; returns you as saved.
  Future<Either<Failure, AppUser>> updateProfile(UpdateProfileParams params);

  /// Deletes your account for good (photo and QR files, personal details,
  /// login), keeping what others share with you; then signs out.
  Future<Either<Failure, Unit>> deleteAccount();

  Future<Either<Failure, Unit>> signOut();

  /// The signed-in user, or `null` when signed out — updates on sign-in,
  /// sign-out, and session restore at app start.
  Stream<AppUser?> get authStateChanges;
}
