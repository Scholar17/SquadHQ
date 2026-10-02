import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._remoteDataSource);

  final NotificationRemoteDataSource _remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications() =>
      _guard(_remoteDataSource.getNotifications);

  @override
  Future<Either<Failure, Unit>> markRead({Set<String>? ids}) => _guard(() async {
        await _remoteDataSource.markRead(ids: ids);
        return unit;
      });

  @override
  Stream<void> watch() => _remoteDataSource.watch();
}
