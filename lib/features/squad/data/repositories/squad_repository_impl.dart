import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/expense_comment.dart';
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
  Future<Either<Failure, List<ExpenseComment>>> getComments(String expenseId) =>
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
