import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/app_notification.dart';
import '../repositories/notification_repository.dart';

class GetNotifications implements UseCase<List<AppNotification>, NoParams> {
  const GetNotifications(this._repository);

  final NotificationRepository _repository;

  @override
  Future<Either<Failure, List<AppNotification>>> call(NoParams params) =>
      _repository.getNotifications();
}
