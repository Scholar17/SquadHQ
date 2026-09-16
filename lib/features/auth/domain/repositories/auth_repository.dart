import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';

abstract interface class AuthRepository {
  /// Launches Facebook's browser sign-in; success/failure of the sign-in
  /// itself arrives later via [authStateChanges], not this call's result.
  Future<Either<Failure, Unit>> signInWithFacebook();

  Future<Either<Failure, AppUser>> signInWithGoogle();

  Future<Either<Failure, AppUser>> completeOnboarding({
    required String userId,
    required String phone,
    required String username,
  });

  Future<Either<Failure, Unit>> signOut();

  /// The signed-in user, or `null` when signed out — updates on sign-in,
  /// sign-out, and session restore at app start.
  Stream<AppUser?> get authStateChanges;
}
