import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// Streams (not a one-shot [UseCase]) so [AuthBloc] can react to sign-in,
/// sign-out and restored sessions as they happen.
class WatchAuthState {
  const WatchAuthState(this._repository);

  final AuthRepository _repository;

  Stream<AppUser?> call() => _repository.authStateChanges;
}
