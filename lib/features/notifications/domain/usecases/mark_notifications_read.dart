import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/notification_repository.dart';

/// Marks the given notification ids read; null marks them all ("Read all").
class MarkNotificationsRead implements UseCase<Unit, Set<String>?> {
  const MarkNotificationsRead(this._repository);

  final NotificationRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(Set<String>? ids) => _repository.markRead(ids: ids);
}
