import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../comments/domain/entities/comment.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/entities/squad_member.dart';
import '../../domain/repositories/squad_repository.dart';
import '../datasources/squad_remote_data_source.dart';

class SquadRepositoryImpl implements SquadRepository {
  const SquadRepositoryImpl(this._remoteDataSource);

  final SquadRemoteDataSource _remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  Future<Either<Failure, Unit>> _done(Future<void> Function() action) => _guard(() async {
    await action();
    return unit;
  });

  @override
  Future<Either<Failure, SquadLedger>> getLedger(String teamId) =>
      _guard(() => _remoteDataSource.getLedger(teamId));

  @override
  Future<Either<Failure, String>> saveExpense(ExpenseDraft draft) =>
      _guard(() => _remoteDataSource.saveExpense(draft));

  @override
  Future<Either<Failure, Unit>> deleteExpense(String expenseId) =>
      _done(() => _remoteDataSource.deleteExpense(expenseId));

  @override
  Future<Either<Failure, String>> saveTrip(TripDraft draft) =>
      _guard(() => _remoteDataSource.saveTrip(draft));

  @override
  Future<Either<Failure, Unit>> setTripClosed(String tripId, {required bool closed}) =>
      _done(() => _remoteDataSource.setTripClosed(tripId, closed: closed));

  @override
  Future<Either<Failure, String>> saveRecurring(RecurringDraft draft) =>
      _guard(() => _remoteDataSource.saveRecurring(draft));

  @override
  Future<Either<Failure, Unit>> setRecurringPaused(String id, {required bool paused}) =>
      _done(() => _remoteDataSource.setRecurringPaused(id, paused: paused));

  @override
  Future<Either<Failure, Unit>> deleteRecurring(String id) =>
      _done(() => _remoteDataSource.deleteRecurring(id));

  @override
  Future<Either<Failure, Unit>> sendSettlement(SettlementDraft draft) =>
      _done(() => _remoteDataSource.sendSettlement(draft));

  @override
  Future<Either<Failure, Unit>> respondSettlement({
    required String settlementId,
    required bool accept,
    String? reason,
  }) => _done(
    () => _remoteDataSource.respondSettlement(
      settlementId: settlementId,
      accept: accept,
      reason: reason,
    ),
  );

  @override
  Future<Either<Failure, int>> remind({
    required String teamId,
    required Map<String, int> amounts,
    String? tripId,
  }) => _guard(() => _remoteDataSource.remind(teamId: teamId, amounts: amounts, tripId: tripId));

  @override
  Future<Either<Failure, Unit>> nudgeSettlement(String settlementId) =>
      _done(() => _remoteDataSource.nudgeSettlement(settlementId));

  @override
  Future<Either<Failure, Unit>> promisePayment(PromiseDraft draft) =>
      _done(() => _remoteDataSource.promisePayment(draft));

  @override
  Future<Either<Failure, Unit>> recordReceived(ReceivedDraft draft) =>
      _done(() => _remoteDataSource.recordReceived(draft));

  @override
  Future<Either<Failure, Unit>> confirmPartialPayment({
    required String settlementId,
    required int receivedCents,
  }) => _done(
    () => _remoteDataSource.confirmPartialPayment(
      settlementId: settlementId,
      receivedCents: receivedCents,
    ),
  );

  @override
  Future<Either<Failure, Unit>> setReminderDay({required String teamId, int? day}) =>
      _done(() => _remoteDataSource.setReminderDay(teamId: teamId, day: day));

  @override
  Future<Either<Failure, List<Comment>>> getComments(String expenseId) =>
      _guard(() => _remoteDataSource.getComments(expenseId));

  @override
  Future<Either<Failure, Unit>> addComment({
    required String expenseId,
    required String body,
    String? parentId,
  }) => _done(
    () => _remoteDataSource.addComment(expenseId: expenseId, body: body, parentId: parentId),
  );

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId) =>
      _done(() => _remoteDataSource.deleteComment(commentId));

  @override
  Future<Either<Failure, BankDetails>> getMyBankDetails() =>
      _guard(_remoteDataSource.getMyBankDetails);

  @override
  Future<Either<Failure, Unit>> saveMyBankDetails(BankDetails details) =>
      _done(() => _remoteDataSource.saveMyBankDetails(details));
}
