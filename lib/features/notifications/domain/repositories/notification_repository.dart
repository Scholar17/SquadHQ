import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_notification.dart';

abstract interface class NotificationRepository {
  /// The signed-in player's most recent notifications, newest first.
  Future<Either<Failure, List<AppNotification>>> getNotifications();

  /// Marks [ids] read — or, if null, every unread notification.
  Future<Either<Failure, Unit>> markRead({Set<String>? ids});

  /// Emits whenever the signed-in player's notifications change on the
  /// server (a new one arrives, or another device reads them). Carries no
  /// data — reload to see what changed.
  Stream<void> watch();
}
