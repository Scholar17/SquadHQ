import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/notifications/domain/entities/app_notification.dart';
import 'package:squad_hq/features/notifications/domain/repositories/notification_repository.dart';

/// In-memory [NotificationRepository]. Seed [items] (newest first); call
/// [arrive] to simulate a new one coming in over Realtime.
class FakeNotificationRepository implements NotificationRepository {
  final items = <AppNotification>[];
  final _changes = StreamController<void>.broadcast();

  void reset() => items.clear();

  void arrive(AppNotification notification) {
    items.insert(0, notification);
    _changes.add(null);
  }

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications() async =>
      Right(List.of(items));

  @override
  Future<Either<Failure, Unit>> markRead({Set<String>? ids}) async {
    final now = DateTime.now();
    for (final (index, item) in items.indexed) {
      if (ids == null || ids.contains(item.id)) items[index] = item.markedRead(now);
    }
    return const Right(unit);
  }

  @override
  Stream<void> watch() => _changes.stream;
}
