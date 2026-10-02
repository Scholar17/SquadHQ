import '../repositories/notification_repository.dart';

/// A stream rather than a UseCase: it emits each time the player's
/// notifications may have changed, until cancelled.
class WatchNotifications {
  const WatchNotifications(this._repository);

  final NotificationRepository _repository;

  Stream<void> call() => _repository.watch();
}
